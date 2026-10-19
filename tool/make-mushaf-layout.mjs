#!/usr/bin/env node
// Turns the quran-qcf4 npm package (MIT data, King Fahd Complex Madina
// 1441H page data) into a small line-layout file the content pipeline uses:
// which words of each ayah sit on which page and line, and where the surah
// headers and basmalas go. The Quran text itself is NOT taken from here; the
// pipeline fills these lines with the verified QuranEnc Arabic.
//
// Usage:  npm pack quran-qcf4@1.1.0 && tar xzf quran-qcf4-1.1.0.tgz
//         node tool/make-mushaf-layout.mjs package
import { readFile, writeFile } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { skeletonLength } from '../pipeline/lib.mjs';

const pkgDir = process.argv[2];
if (!pkgDir) throw new Error('Pass the extracted quran-qcf4 package folder');
const here = dirname(fileURLToPath(import.meta.url));
const OUT = join(here, '..', 'pipeline', 'data', 'madina-1441h-layout.json');

const pkg = JSON.parse(await readFile(join(pkgDir, 'package.json'), 'utf8'));
// key -> [[page, line, wordCount, letterCount]] in qcf word positions. The
// letter counts let the pipeline place words when the two texts split a
// word differently (for example لوما written as two words).
const verses = {};
const specials = {}; // page -> [[line, 'h' | 'b', surah]]
const linesPerPage = {};

for (let p = 1; p <= 604; p++) {
  const page = JSON.parse(await readFile(join(pkgDir, 'pages', `${String(p).padStart(3, '0')}.json`), 'utf8'));
  let maxLine = 0;
  for (const l of page.lines) {
    maxLine = Math.max(maxLine, l.line);
    for (const w of l.words) {
      if (w.type === 'surah_header' || w.type === 'bismillah') {
        (specials[p] ??= []).push([l.line, w.type === 'surah_header' ? 'h' : 'b', Number(w.sura ?? w.surah)]);
      } else if (w.type === 'word') {
        const runs = (verses[w.verse_key] ??= []);
        const last = runs[runs.length - 1];
        const letters = skeletonLength(w.text);
        if (last && last[0] === p && last[1] === l.line) {
          last[2]++;
          last[3] += letters;
        } else runs.push([p, l.line, 1, letters]);
      }
    }
  }
  linesPerPage[p] = maxLine;
}

const keys = Object.keys(verses);
if (keys.length !== 6236) throw new Error(`Expected 6236 verses, got ${keys.length}`);
for (const [p, list] of Object.entries(specials)) {
  for (const [, , s] of list) if (!(s >= 1 && s <= 114)) throw new Error(`Bad surah on page ${p}`);
}

const out = {
  layout: 'Madina Mushaf 1441H (15 lines)',
  source: {
    name: 'quran-qcf4',
    version: pkg.version,
    url: 'https://www.npmjs.com/package/quran-qcf4',
    license: 'MIT',
    copyright: 'Copyright (c) 2026 Mohamad Hajj Rabee',
    note: 'Line and page boundaries only, from King Fahd Glorious Quran Printing Complex page data.',
  },
  pages: 604,
  linesPerPage,
  specials,
  verses,
};
await writeFile(OUT, JSON.stringify(out) + '\n', 'utf8');
console.log(`Wrote ${OUT}`);
