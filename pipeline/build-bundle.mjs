#!/usr/bin/env node
// Builds app/assets/content/bundle.json from QuranEnc and HadeethEnc.
// Usage (from the project root):  node pipeline/build-bundle.mjs
// Needs Node 18+ (built-in fetch). No npm packages.

import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  QURANENC, HADEETHENC, extractList, findTranslationMeta, buildSurah,
  hasAllLanguages, buildHadith, buildQuranDua, validateBundle,
} from './lib.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const OUT = join(here, '..', 'app', 'assets', 'content', 'bundle.json');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Polite fetch: one request at a time, small pause, three retries.
export async function fetchJson(url, { retries = 3, pauseMs = 250 } = {}) {
  for (let attempt = 1; ; attempt++) {
    try {
      await sleep(pauseMs);
      const res = await fetch(url, { headers: { Accept: 'application/json' } });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return await res.json();
    } catch (err) {
      if (attempt >= retries) throw new Error(`${url}: ${err.message}`);
      await sleep(1000 * attempt);
    }
  }
}

export async function build(config, get = fetchJson, log = console.log) {
  // Required languages must exist for every item; optional ones are added
  // per item when the source has them (the app falls back to the first
  // required language).
  const langs = config.languages;
  const optional = config.optionalLanguages ?? [];
  const allLangs = [...langs, ...optional];
  const keys = config.quranTranslations;
  const warnings = [];

  // Sources and their versions (QuranEnc terms: show version, keep updated).
  const sources = {};
  for (const lang of allLangs) {
    const list = await get(`${QURANENC}/translations/list/${lang}`);
    const meta = findTranslationMeta(list, keys[lang]);
    sources[keys[lang]] = {
      publisher: 'QuranEnc.com',
      title: meta.title,
      version: meta.version,
      url: 'https://quranenc.com',
    };
  }
  sources.hadeethenc = {
    publisher: 'HadeethEnc.com',
    title: 'Encyclopedia of Translated Prophetic Hadiths',
    url: 'https://hadeethenc.com',
  };

  // Surahs
  const surahs = [];
  for (const s of config.surahs) {
    const rowsByLang = {};
    for (const lang of allLangs) {
      rowsByLang[lang] = extractList(await get(`${QURANENC}/translation/sura/${keys[lang]}/${s.number}`));
    }
    const { surah, warnings: w } = buildSurah(s, rowsByLang, keys);
    warnings.push(...w);
    surahs.push(surah);
    log(`surah ${s.number}: ${surah.ayat.length} ayat`);
  }

  // Hadith that exist in every required language, with optional languages
  // added where HadeethEnc has them.
  async function hadithFromCategory(categoryId, max) {
    const picked = [];
    for (let page = 1; picked.length < max; page++) {
      const res = await get(`${HADEETHENC}/hadeeths/list/?language=${langs[0]}&category_id=${categoryId}&page=${page}&per_page=50`);
      for (const item of res.data ?? []) {
        if (picked.length >= max) break;
        if (hasAllLanguages(item, langs)) picked.push(item);
        else log(`  skip hadith ${item.id}: not in all of ${langs.join(', ')}`);
      }
      if (page >= Number(res.meta?.last_page ?? 1)) break;
    }
    const out = [];
    for (const item of picked) {
      const detail = {};
      for (const lang of allLangs) {
        if (!(item.translations ?? []).includes(lang)) continue;
        detail[lang] = await get(`${HADEETHENC}/hadeeths/one/?id=${item.id}&language=${lang}`);
      }
      out.push(detail);
    }
    return out;
  }

  const hadith = [];
  for (const g of config.hadithGroups) {
    for (const d of await hadithFromCategory(g.categoryId, g.max)) {
      hadith.push(buildHadith(d, { group: g.id }));
    }
    log(`hadith group ${g.id}: ${hadith.filter((h) => h.group === g.id).length}`);
  }

  // Duas
  const duas = [];
  const seen = new Set();
  for (const c of config.duaCategories) {
    for (const d of await hadithFromCategory(c.categoryId, 50)) {
      const h = buildHadith(d);
      if (seen.has(h.hadeethencId)) continue;
      seen.add(h.hadeethencId);
      duas.push({ ...h, id: `dua-${h.id}`, kind: 'hadith', moment: c.moment });
    }
    log(`dua moment ${c.moment}: ${duas.filter((x) => x.moment === c.moment).length}`);
  }
  for (const q of config.quranDuas) {
    const rowByLang = {};
    for (const lang of allLangs) {
      rowByLang[lang] = await get(`${QURANENC}/translation/aya/${keys[lang]}/${q.sura}/${q.aya}`);
      if (rowByLang[lang]?.result && !rowByLang[lang].translation) rowByLang[lang] = rowByLang[lang].result;
    }
    duas.push(buildQuranDua(q, rowByLang, keys));
  }

  const now = new Date();
  const bundle = {
    bundleVersion: now.toISOString().slice(0, 19).replace(/[-:T]/g, ''),
    generatedAt: now.toISOString(),
    languages: langs,
    optionalLanguages: optional,
    sources,
    surahs,
    hadith,
    duas,
  };
  return { bundle, warnings, errors: validateBundle(bundle, langs) };
}

async function main() {
  const config = JSON.parse(await readFile(join(here, 'config.json'), 'utf8'));
  const { bundle, warnings, errors } = await build(config);
  warnings.forEach((w) => console.warn(`warning: ${w}`));
  if (errors.length) {
    errors.forEach((e) => console.error(`error: ${e}`));
    console.error(`\nBundle NOT written: ${errors.length} problem(s).`);
    process.exit(1);
  }
  await mkdir(dirname(OUT), { recursive: true });
  await writeFile(OUT, JSON.stringify(bundle, null, 2) + '\n', 'utf8');
  console.log(`\nWrote ${OUT}`);
  const opt = (bundle.optionalLanguages ?? []).map((l) => {
    const n = [...bundle.hadith, ...bundle.duas].filter((x) => x[l] || x.meaning?.[l]).length;
    return `${l}: ${n} of ${bundle.hadith.length + bundle.duas.length} hadith and duas`;
  });
  console.log(`${bundle.surahs.length} surahs, ${bundle.hadith.length} hadith, ${bundle.duas.length} duas` +
    (opt.length ? ` (${opt.join('; ')})` : ''));
}

const samePath = (a, b) => resolve(a).toLowerCase() === resolve(b).toLowerCase();
if (process.argv[1] && samePath(fileURLToPath(import.meta.url), process.argv[1])) {
  main().catch((err) => { console.error(err.message); process.exit(1); });
}
