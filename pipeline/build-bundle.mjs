#!/usr/bin/env node
// Builds app/assets/content/bundle.json from QuranEnc and HadeethEnc.
// Usage (from the project root):  node pipeline/build-bundle.mjs
// Needs Node 18+ (built-in fetch). No npm packages.

import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  QURANENC, HADEETHENC, extractList, findTranslationMeta, buildSurah,
  hasAllLanguages, buildHadith, buildQuranDua, validateBundle, surahConfigsFromMeta, juzOfSurahs,
  attachMushaf, normalizeArabic, trigrams, hadithQuote, namedCollections, bestMatches,
  decideRef, needsAdultReview,
} from './lib.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const OUT = join(here, '..', 'app', 'assets', 'content', 'bundle.json');
const REPORT = join(here, 'reports', 'hadith-report.json');

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

export async function headOk(url) {
  try {
    const res = await fetch(url, { method: 'HEAD' });
    return res.ok;
  } catch {
    return false;
  }
}

export async function build(config, get = fetchJson, log = console.log, head = headOk) {
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

  // Surahs: either a fixed list or all 114 from AlQuran.cloud metadata
  const surahCfgs = config.surahs === 'all'
    ? surahConfigsFromMeta(await get(config.surahMetaUrl))
    : config.surahs;
  if (config.quranMetaUrl) {
    const juz = juzOfSurahs(await get(config.quranMetaUrl));
    for (const s of surahCfgs) s.juz = juz[s.number];
  }
  const surahs = [];
  for (const s of surahCfgs) {
    const rowsByLang = {};
    for (const lang of allLangs) {
      rowsByLang[lang] = extractList(await get(`${QURANENC}/translation/sura/${keys[lang]}/${s.number}`));
    }
    const { surah, warnings: w } = buildSurah(s, rowsByLang, keys);
    if (s.ayahCount) surah.ayahCount = s.ayahCount;
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
        const url = `${HADEETHENC}/hadeeths/one/?id=${item.id}&language=${lang}`;
        if (langs.includes(lang)) {
          detail[lang] = await get(url);
          continue;
        }
        // Optional language: HadeethEnc sometimes lists a translation it
        // does not serve (#21). Leave it out; the app falls back to English.
        try {
          detail[lang] = await get(url);
        } catch (err) {
          warnings.push(`hadith ${item.id}: no ${lang} text (${err.message}); left out`);
        }
      }
      out.push(detail);
    }
    return out;
  }

  // Category names come from HadeethEnc itself, in each language.
  const categoryTitles = {};
  for (const lang of (config.hadithShelves ?? []).length ? allLangs : []) {
    let list = [];
    try {
      list = extractList(await get(`${HADEETHENC}/categories/list/?language=${lang}`));
    } catch (err) {
      if (langs.includes(lang)) throw err;
    }
    for (const c of list) (categoryTitles[String(c.id)] ??= {})[lang] = c.title;
  }

  // Hadith shelves: kid-friendly groups of HadeethEnc categories. Bulk
  // categories are screened; anything on an adult topic is left out and
  // listed in the report for a person to decide.
  const hadith = [];
  const shelves = [];
  const heldBack = [];
  const seenHadith = new Set();
  for (const shelf of config.hadithShelves ?? []) {
    const topics = [];
    for (const t of shelf.topics) {
      const title = categoryTitles[String(t.categoryId)];
      if (!title?.[langs[0]]) throw new Error(`HadeethEnc has no category ${t.categoryId} (${t.id})`);
      let count = 0;
      for (const d of await hadithFromCategory(t.categoryId, t.max * 2)) {
        if (count >= t.max) break;
        const h = buildHadith(d, { group: t.id });
        if (seenHadith.has(h.hadeethencId)) continue;
        const en = h[langs[0]];
        if (needsAdultReview(`${en.title} ${en.text} ${en.explanation} ${(en.hints ?? []).join(' ')}`)) {
          heldBack.push({ id: h.hadeethencId, topic: t.id, title: en.title });
          continue;
        }
        seenHadith.add(h.hadeethencId);
        hadith.push(h);
        count++;
      }
      topics.push({ id: t.id, categoryId: t.categoryId, title });
      log(`hadith ${shelf.id}/${t.id}: ${count}`);
    }
    shelves.push({ id: shelf.id, topics });
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

  // Audio: per-ayah files on the AlQuran.cloud CDN, named by global ayah
  // number. Use the smallest published bitrate that answers.
  // Each reciter is checked at the first and the last ayah, so a reciter
  // with gaps on the CDN is not offered.
  let audio = null;
  const reciters = [];
  if (config.audio) {
    const a = config.audio;
    const probe = async (r) => {
      for (const bitrate of r.bitrates ?? a.bitrates) {
        const at = (n) => `${a.base}/${bitrate}/${r.edition}/${n}.mp3`;
        if (await head(at(1)) && await head(at(6236))) {
          return {
            urlTemplate: `${a.base}/${bitrate}/${r.edition}/{n}.mp3`,
            edition: r.edition,
            bitrate,
            reciter: r.reciter,
            ...(r.reciterAr ? { reciterAr: r.reciterAr } : {}),
            publisher: a.publisher,
            terms: a.terms,
          };
        }
      }
      return null;
    };
    audio = await probe(a);
    if (!audio) throw new Error('No audio bitrate answered on the CDN');
    reciters.push(audio);
    log(`audio: ${audio.edition} at ${audio.bitrate} kbps (default)`);
    for (const r of a.others ?? []) {
      const info = await probe(r);
      if (info) {
        reciters.push(info);
        log(`audio: ${info.edition} at ${info.bitrate} kbps`);
      } else {
        warnings.push(`reciter ${r.edition}: no bitrate has both the first and last ayah; left out`);
      }
    }
  }

  // Bukhari and Muslim numbers for every hadith and hadith dua.
  const refReport = [];
  if (config.hadithRefs) {
    const r = config.hadithRefs;
    const manual = r.manualFile ? JSON.parse(await readFile(join(here, r.manualFile), 'utf8')) : {};
    const indexes = {};
    for (const [collection, edition] of Object.entries(r.editions)) {
      const json = await get(`${r.base}/${edition}.min.json`);
      indexes[collection] = (json.hadiths ?? [])
        .filter((h) => typeof h.text === 'string' && h.text.trim())
        .map((h) => ({ number: refNumber(collection, h), ref: h.reference, grams: trigrams(normalizeArabic(h.text)) }));
      log(`references: ${collection} ${indexes[collection].length} hadith`);
    }
    for (const item of [...hadith, ...duas.filter((d) => d.kind === 'hadith')]) {
      const quoteGrams = trigrams(normalizeArabic(hadithQuote(item.ar.text)));
      const refs = [];
      const row = { id: item.hadeethencId, attribution: item.ar.attribution, grams: quoteGrams.size, picked: {}, candidates: {} };
      for (const collection of namedCollections(item.ar.attribution)) {
        const candidates = indexes[collection] ? bestMatches(quoteGrams, indexes[collection]) : [];
        row.candidates[collection] = candidates.map((c) => `${c.number} (${c.score.toFixed(2)})`);
        const ref = decideRef({ collection, quoteGrams, candidates, manual: manual[item.hadeethencId] });
        row.picked[collection] = ref ? `${ref.number} ${ref.how}` : null;
        if (ref) refs.push(ref);
      }
      item.refs = refs;
      refReport.push(row);
    }
    sources.hadithRefs = {
      publisher: r.publisher,
      title: r.title,
      url: r.url,
      version: r.version,
    };
    const unmatched = refReport.filter((x) => Object.values(x.picked).some((v) => v === null)).length;
    log(`references: ${refReport.length - unmatched} of ${refReport.length} fully numbered`);
  }

  // Madina mushaf pages: line breaks from the layout file, words from the
  // QuranEnc Arabic above.
  let mushaf = null;
  if (config.mushafLayout) {
    const layout = JSON.parse(await readFile(join(here, config.mushafLayout), 'utf8'));
    mushaf = attachMushaf(surahs, layout);
    sources.mushafLayout = {
      publisher: layout.source.name,
      title: `${layout.layout}, ${layout.source.license}, ${layout.source.copyright}`,
      version: layout.source.version,
      url: layout.source.url,
    };
    log(`mushaf: ${mushaf.placed} ayat on ${mushaf.pages} pages`);
  }

  const now = new Date();
  const bundle = {
    // Bump only when the app can no longer read the old shape. Old app
    // versions ignore published bundles with a schema they do not know.
    schemaVersion: 1,
    bundleVersion: now.toISOString().slice(0, 19).replace(/[-:T]/g, ''),
    generatedAt: now.toISOString(),
    languages: langs,
    optionalLanguages: optional,
    sources,
    audio,
    reciters,
    mushaf,
    surahs,
    shelves,
    hadith,
    duas,
  };
  const report = { references: refReport, heldBack };
  return { bundle, warnings, report, errors: validateBundle(bundle, langs) };
}

// Bukhari by its usual (Fath al-Bari) number; Muslim by Muhammad Fu'ad
// Abd al-Baqi's number, which the source gives as "2022" or "2022.01".
// Bukhari sometimes carries a sub-number ("5051.2"); the citation is 5051.
function refNumber(collection, h) {
  const raw = collection === 'muslim' ? (h.arabicnumber ?? h.hadithnumber) : h.hadithnumber;
  return parseInt(String(raw), 10);
}

async function main() {
  const config = JSON.parse(await readFile(join(here, 'config.json'), 'utf8'));
  const { bundle, warnings, errors, report } = await build(config);
  warnings.forEach((w) => console.warn(`warning: ${w}`));
  // The reference report is for people: which numbers were matched, which
  // need checking, and which hadith were held back for adult review.
  await mkdir(dirname(REPORT), { recursive: true });
  await writeFile(REPORT, JSON.stringify(report, null, 2) + '\n', 'utf8');
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
