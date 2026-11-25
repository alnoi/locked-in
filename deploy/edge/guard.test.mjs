import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';

function fixture() {
  let time = 1800000000000;
  function dictionary(timeout) {
    const entries = new Map();
    return {
      get(key) { const entry = entries.get(key); return entry && entry.until > time ? entry.value : undefined; },
      set(key, value) { entries.set(key, {value, until: time + timeout}); },
      add(key, value) { if (this.get(key) !== undefined) return false; this.set(key, value); return true; },
      incr(key, value) { this.set(key, this.get(key) + value); return this; },
      delete(key) { entries.delete(key); },
    };
  }
  const context = vm.createContext({Date: {now: () => time}, ngx: {
    shared: {trackit_bans: dictionary(600000), trackit_failures: dictionary(120000)}, log() {}, WARN: 4,
  }});
  const source = readFileSync(new URL('./guard.js', import.meta.url), 'utf8').replace('export default', 'globalThis.guard =');
  vm.runInContext(source, context);
  const request = (ip = '198.51.100.5', extra = {}) => ({remoteAddress: ip, headersOut: {}, args: {},
    return(status, body) { this.result = {status, body}; }, ...extra});
  const flood = (ip) => { for (let i = 0; i < 10; i++) context.guard.rateLimited(request(ip)); };
  return {guard: context.guard, request, flood, advance: (milliseconds) => { time += milliseconds; }};
}

test('repeated rate violations block the source IP for ten minutes and then expire', () => {
  const f = fixture();
  for (let i = 0; i < 9; i++) f.guard.rateLimited(f.request());
  let r = f.request(); f.guard.check(r); assert.equal(r.result.status, 204);
  f.guard.rateLimited(f.request());
  r = f.request(); f.guard.check(r); assert.equal(r.result.status, 403);
  r = f.request(); f.guard.blocked(r); assert.equal(r.result.status, 429); assert.equal(r.headersOut['Retry-After'], '600');
  assert.equal(JSON.parse(r.result.body).code, 'rate_limited');
  r = f.request('198.51.100.6'); f.guard.check(r); assert.equal(r.result.status, 204);
  f.advance(600001);
  r = f.request(); f.guard.check(r); assert.equal(r.result.status, 204);
});
test('requests during a ban do not extend its duration', () => {
  const f = fixture(); f.flood(); f.advance(30000);
  const r = f.request(); f.guard.rateLimited(r); assert.equal(r.headersOut['Retry-After'], '570');
});
test('only failed authentication responses count as password failures', () => {
  const f = fixture();
  for (let i = 0; i < 20; i++) f.guard.recordResponse(f.request(undefined, {status: 401, uri: '/api/v1/tasks'}));
  let r = f.request(); f.guard.check(r); assert.equal(r.result.status, 204);
  for (let i = 0; i < 10; i++) f.guard.recordResponse(f.request(undefined, {status: 401, uri: '/api/v1/auth/login'}));
  r = f.request(); f.guard.check(r); assert.equal(r.result.status, 403);
});
test('forged forwarded headers cannot select a different IP for banning', () => {
  const f = fixture();
  for (let i = 0; i < 10; i++) f.guard.rateLimited(f.request(undefined, {headersIn: {'X-Real-IP': '198.51.100.6'}}));
  let r = f.request('198.51.100.6'); f.guard.check(r); assert.equal(r.result.status, 204);
  r = f.request(); f.guard.check(r); assert.equal(r.result.status, 403);
});
test('failures from an older minute do not accumulate forever', () => {
  const f = fixture();
  for (let i = 0; i < 9; i++) f.guard.rateLimited(f.request());
  f.advance(60001); f.guard.rateLimited(f.request());
  const r = f.request(); f.guard.check(r); assert.equal(r.result.status, 204);
});
test('the private control handler removes one ban and resets its recent failures', () => {
  const f = fixture(); f.flood('2001:db8::5');
  let r = f.request(undefined, {method: 'GET', args: {ip: '2001:db8::5'}}); f.guard.admin(r);
  assert.equal(JSON.parse(r.result.body).retryAfter, 600);
  r = f.request(undefined, {method: 'DELETE', args: {ip: '2001:db8::5'}}); f.guard.admin(r); assert.equal(r.result.status, 204);
  r = f.request('2001:db8::5'); f.guard.check(r); assert.equal(r.result.status, 204);
  f.guard.rateLimited(f.request('2001:db8::5'));
  r = f.request('2001:db8::5'); f.guard.check(r); assert.equal(r.result.status, 204);
});
