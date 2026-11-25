const banMilliseconds = 600000;
const windowMilliseconds = 60000;
const maximumFailures = 10;
const rateMessage = JSON.stringify({code: 'rate_limited', message: 'Too many attempts. Please wait and try again.'});

function remaining(address) {
  return Math.max(0, Math.ceil(((ngx.shared.trackit_bans.get(address) || 0) - Date.now()) / 1000));
}
function recordFailure(address) {
  if (remaining(address)) return;
  const key = address + ':' + Math.floor(Date.now() / windowMilliseconds);
  const failures = ngx.shared.trackit_failures;
  if (!failures.add(key, 1)) failures.incr(key, 1);
  if (failures.get(key) >= maximumFailures) {
    ngx.shared.trackit_bans.set(address, Date.now() + banMilliseconds);
    ngx.log(ngx.WARN, 'TrackIt temporarily blocked ' + address + ' for 600 seconds');
  }
}
function check(request) {
  request.return(remaining(request.remoteAddress) ? 403 : 204);
}
function blocked(request) {
  request.headersOut['Content-Type'] = 'application/json';
  request.headersOut['Retry-After'] = String(remaining(request.remoteAddress) || 60);
  request.return(429, rateMessage);
}
function rateLimited(request) {
  recordFailure(request.remoteAddress);
  blocked(request);
}
function recordResponse(request) {
  if (request.status === 401 && /^\/api\/v1\/auth\/(login|register)$/.test(request.uri)) {
    recordFailure(request.remoteAddress);
  }
}
function notFound(request) {
  recordFailure(request.remoteAddress);
  request.headersOut['Content-Type'] = 'application/json';
  request.return(404, JSON.stringify({code: 'not_found', message: 'The requested item is no longer available.'}));
}
function admin(request) {
  const address = request.args.ip;
  if (typeof address !== 'string' || !/^[0-9a-f:.]{3,64}$/i.test(address)) {
    request.return(400);
    return;
  }
  if (request.method === 'DELETE') {
    ngx.shared.trackit_bans.delete(address);
    const bucket = Math.floor(Date.now() / windowMilliseconds);
    ngx.shared.trackit_failures.delete(address + ':' + bucket);
    ngx.shared.trackit_failures.delete(address + ':' + (bucket - 1));
    request.return(204);
    return;
  }
  if (request.method !== 'GET') {
    request.return(405);
    return;
  }
  request.headersOut['Content-Type'] = 'application/json';
  request.return(200, JSON.stringify({retryAfter: remaining(address)}));
}
export default {check, blocked, rateLimited, recordResponse, notFound, admin};
