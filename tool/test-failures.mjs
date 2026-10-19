#!/usr/bin/env node
// Turns a `flutter test --file-reporter json:<file>` report into one GitHub
// error annotation per failing test (name + first lines of the error), since
// CI logs cannot be read from outside GitHub.
// Usage: node tool/test-failures.mjs app/test-results.json
import { readFileSync } from 'node:fs';

export function failures(jsonLines) {
  const names = new Map();
  const errors = new Map();
  const prints = new Map();
  const failed = [];
  for (const line of jsonLines.split('\n')) {
    if (!line.trim().startsWith('{')) continue;
    let e;
    try { e = JSON.parse(line); } catch { continue; }
    if (e.type === 'testStart') names.set(e.test.id, e.test.name);
    if (e.type === 'error') errors.set(e.testID, [...(errors.get(e.testID) ?? []), e.error]);
    // Framework exceptions (overflow, assertion) arrive as print events.
    if (e.type === 'print' && /EXCEPTION|overflowed|was thrown|Assertion|Error|Warning/.test(e.message)) {
      prints.set(e.testID, [...(prints.get(e.testID) ?? []), e.message]);
    }
    if (e.type === 'testDone' && e.result !== 'success' && !e.hidden) failed.push(e.testID);
  }
  return failed.map((id) => ({
    name: names.get(id) ?? `test ${id}`,
    error: [...(prints.get(id) ?? []), ...(errors.get(id) ?? [])].join('\n'),
  }));
}

const enc = (s) => s.replace(/%/g, '%25').replace(/\r/g, '%0D').replace(/\n/g, '%0A');

const file = process.argv[2];
if (file) {
  const list = failures(readFileSync(file, 'utf8'));
  for (const f of list) {
    const msg = f.error.split('\n').filter((l) => l.trim() && !/^[═╡╞ ]*$/.test(l)).slice(0, 14).join('\n');
    console.log(`::error title=Test failed: ${enc(f.name).slice(0, 200)}::${enc(msg)}`);
  }
  console.log(`${list.length} failing test(s)`);
}
