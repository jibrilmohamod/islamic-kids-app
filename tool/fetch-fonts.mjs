#!/usr/bin/env node
// Downloads the app's fonts (all SIL Open Font License) into app/assets/fonts
// so the app never fetches fonts at runtime and works fully offline.
// Usage: node tool/fetch-fonts.mjs
import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const out = join(dirname(fileURLToPath(import.meta.url)), '..', 'app', 'assets', 'fonts');

// family query -> { weight: file name }
const FONTS = [
  { query: 'Bungee', files: { 400: 'Bungee-Regular.ttf' }, license: 'bungee' },
  { query: 'Baloo+2:wght@500;700;800', files: { 500: 'Baloo2-Medium.ttf', 700: 'Baloo2-Bold.ttf', 800: 'Baloo2-ExtraBold.ttf' }, license: 'baloo2' },
  { query: 'Amiri+Quran', files: { 400: 'AmiriQuran-Regular.ttf' }, license: 'amiriquran', prefer: 'arabic' },
];

async function get(url, as = 'text') {
  // A plain user agent makes Google Fonts answer with whole TTF files.
  const res = await fetch(url, { headers: { 'User-Agent': 'curl/8' } });
  if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
  return as === 'bytes' ? new Uint8Array(await res.arrayBuffer()) : res.text();
}

// Returns { weight: url } from a css2 response: the whole font when Google
// sends one, else the subset named by [prefer] (arabic for the Quran font).
export function ttfUrls(css, prefer = 'latin') {
  const found = {};
  const re = /(?:\/\*\s*([\w-]+)\s*\*\/\s*)?@font-face\s*\{([^}]*)\}/g;
  for (const [, subset, block] of css.matchAll(re)) {
    const weight = Number(block.match(/font-weight:\s*(\d+)/)?.[1]);
    const url = block.match(/url\((https:[^)]+\.ttf)\)/)?.[1];
    if (!weight || !url) continue;
    // A block without unicode-range is the whole font: always best.
    const score = !/unicode-range/.test(block) ? 2 : subset === prefer ? 1 : 0;
    if (!found[weight] || score > found[weight].score) found[weight] = { url, score };
  }
  return Object.fromEntries(Object.entries(found).map(([w, v]) => [w, v.url]));
}

async function main() {
  await mkdir(out, { recursive: true });
  const licenses = [];
  for (const font of FONTS) {
    const urls = ttfUrls(await get(`https://fonts.googleapis.com/css2?family=${font.query}`), font.prefer);
    for (const [weight, file] of Object.entries(font.files)) {
      if (!urls[weight]) throw new Error(`${font.query}: no TTF for weight ${weight}`);
      await writeFile(join(out, file), await get(urls[weight], 'bytes'));
      console.log(`${file}`);
    }
    const ofl = await get(`https://raw.githubusercontent.com/google/fonts/main/ofl/${font.license}/OFL.txt`);
    licenses.push(`${font.license}\n\n${ofl}`);
  }
  await writeFile(join(out, 'OFL-licenses.txt'), licenses.join('\n\n----------\n\n'));
  console.log('OFL-licenses.txt');
}

const samePath = (a, b) => a.toLowerCase() === b.toLowerCase();
if (process.argv[1] && samePath(fileURLToPath(import.meta.url), process.argv[1])) {
  main().catch((e) => { console.error(e.message); process.exit(1); });
}
