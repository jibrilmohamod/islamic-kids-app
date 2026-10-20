// Coverage as a report, never a gate (test audit T8).
//
//   node tool/coverage-report.mjs app/coverage/lcov.info app/lib
//
// `flutter test --coverage` leaves out files no test imports, so its total
// overstates how much is tested. This adds those files back at 0 % (counting
// their non-blank, non-comment lines), skips generated files, and prints one
// GitHub annotation with the honest total and the least-covered files.
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const [lcovPath, libDir] = process.argv.slice(2);
const covered = new Map(); // file -> [hit, found]
let file = null;
for (const line of readFileSync(lcovPath, 'utf8').split('\n')) {
  if (line.startsWith('SF:')) file = line.slice(3).replace(/^.*?\blib\//, 'lib/');
  else if (line.startsWith('LH:')) covered.set(file, [Number(line.slice(3)), covered.get(file)?.[1] ?? 0]);
  else if (line.startsWith('LF:')) covered.set(file, [covered.get(file)?.[0] ?? 0, Number(line.slice(3))]);
}

const walk = (dir) => readdirSync(dir).flatMap((n) => {
  const p = join(dir, n);
  return statSync(p).isDirectory() ? walk(p) : [p];
});
const generated = /(\.g|\.freezed)\.dart$|pop_icons\.dart$/;
const rows = [];
for (const p of walk(libDir).filter((p) => p.endsWith('.dart') && !generated.test(p))) {
  const key = 'lib/' + relative(libDir, p).replaceAll('\\', '/');
  if (covered.has(key)) {
    const [hit, found] = covered.get(key);
    rows.push({ key, hit, found, untested: false });
  } else {
    const lines = readFileSync(p, 'utf8').split('\n')
      .filter((l) => l.trim() && !l.trim().startsWith('//') && !l.trim().startsWith('import ')).length;
    rows.push({ key, hit: 0, found: lines, untested: true });
  }
}
const hit = rows.reduce((t, r) => t + r.hit, 0);
const found = rows.reduce((t, r) => t + r.found, 0);
const pct = (h, f) => (f ? ((100 * h) / f).toFixed(0) : '100');
const worst = rows.sort((a, b) => a.hit / (a.found || 1) - b.hit / (b.found || 1)).slice(0, 8)
  .map((r) => `${r.key} ${pct(r.hit, r.found)}%${r.untested ? ' (no test imports it)' : ''}`);
const untested = rows.filter((r) => r.untested).length;
console.log(`::notice title=Coverage ${pct(hit, found)}% of ${found} lines (${untested} files no test imports)::Least covered: ${worst.join('; ')}`);
