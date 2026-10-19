// Reads a bundle on stdin and prints it without the per-run stamps, so two
// bundles can be compared on content alone. Used by the CI workflow.
let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => { raw += c; });
process.stdin.on('end', () => {
  const b = JSON.parse(raw);
  delete b.bundleVersion;
  delete b.generatedAt;
  process.stdout.write(JSON.stringify(b, null, 2) + '\n');
});
