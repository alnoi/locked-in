import { readdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { format } from 'sql-formatter';

const check = process.argv.includes('--check');
const options = { language: 'postgresql', keywordCase: 'upper', paramTypes: { named: ['@'] } };
let changed = false;
async function visit(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) { await visit(path); continue; }
    if (!path.endsWith('.go') && !path.endsWith('.sql')) continue;
    const original = await readFile(path, 'utf8');
    const formatted = path.endsWith('.sql')
      ? format(original, options).trimEnd() + '\n'
      : original.replace(/\b((?:const|var)\s+\w*[Qq]uery\w*\s*=\s*)`([^`]+)`/g, (_, declaration, sql) => declaration + '`' + format(sql, options).trimEnd() + '`');
    if (formatted === original) continue;
    changed = true;
    if (check) process.stderr.write(path + ' needs SQL formatting\n');
    else await writeFile(path, formatted);
  }
}
await visit('internal');
await visit('migrations');
if (check && changed) process.exitCode = 1;
