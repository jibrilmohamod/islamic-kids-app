// Pure helpers for the content pipeline. No network access here, so every
// function can be tested against fixtures.
//
// Rule: religious text is copied verbatim from the source APIs. These helpers
// only move fields around and check that nothing is missing. They never edit,
// trim or rewrite the text itself.

export const QURANENC = 'https://quranenc.com/api/v1';
export const HADEETHENC = 'https://hadeethenc.com/api/v1';

// QuranEnc documents its sura response as "json object containing array of
// objects". Accept a bare array, a `result` array, or the first array value.
export function extractList(json) {
  if (Array.isArray(json)) return json;
  if (json && Array.isArray(json.result)) return json.result;
  if (json && typeof json === 'object') {
    const firstArray = Object.values(json).find(Array.isArray);
    if (firstArray) return firstArray;
  }
  throw new Error('Expected a list in the API response');
}

// QuranEnc translation list endpoint: find one translation's metadata by key.
export function findTranslationMeta(listJson, key) {
  const list = Array.isArray(listJson?.translations)
    ? listJson.translations
    : extractList(listJson);
  const meta = list.find((t) => t.key === key);
  if (!meta) throw new Error(`Translation ${key} not found in QuranEnc list`);
  return meta;
}

export function buildSurah(surahCfg, rowsByLang, translationKeys) {
  const langs = Object.keys(rowsByLang);
  const base = rowsByLang[langs[0]];
  const warnings = [];

  const ayat = base.map((row) => {
    const aya = Number(row.aya);
    const meaning = {};
    for (const lang of langs) {
      const match = rowsByLang[lang].find((r) => Number(r.aya) === aya);
      if (!match) throw new Error(`Surah ${surahCfg.number}:${aya} missing in ${lang}`);
      if (match.arabic_text !== row.arabic_text) {
        warnings.push(`Arabic text differs between editions at ${surahCfg.number}:${aya}`);
      }
      meaning[lang] = {
        text: match.translation,
        footnotes: match.footnotes ?? '',
        source: translationKeys[lang],
      };
    }
    // QuranEnc's id is the ayah's position in the whole Quran (1 to 6236),
    // which is also how the audio CDN names its files.
    const n = Number(row.id);
    return { key: `${surahCfg.number}:${aya}`, aya, n: Number.isInteger(n) ? n : null, arabic: row.arabic_text, meaning };
  });

  ayat.sort((a, b) => a.aya - b.aya);
  return {
    surah: {
      id: `surah-${surahCfg.number}`,
      number: surahCfg.number,
      name: surahCfg.name,
      nameAr: surahCfg.nameAr,
      ...(surahCfg.revelation ? { revelation: surahCfg.revelation } : {}),
      ...(surahCfg.nameMeaning ? { nameMeaning: surahCfg.nameMeaning } : {}),
      ...(surahCfg.juz ? { juz: surahCfg.juz } : {}),
      ayat,
    },
    warnings,
  };
}

// AlQuran.cloud surah list -> pipeline surah configs. The Arabic name drops
// the leading word "surah" so the app can show the short name.
export function surahConfigsFromMeta(json) {
  const list = json?.data;
  if (!Array.isArray(list) || list.length !== 114) throw new Error('Expected 114 surahs in metadata');
  return list.map((s) => {
    const revelation = String(s.revelationType ?? '').toLowerCase();
    return {
      number: s.number,
      name: s.englishName,
      nameAr: String(s.name).replace(/^سُورَةُ\s+/, ''),
      ayahCount: s.numberOfAyahs,
      // Surah facts (#28), from the same AlQuran.cloud record.
      ...(revelation === 'meccan' || revelation === 'medinan' ? { revelation } : {}),
      ...(s.englishNameTranslation ? { nameMeaning: { en: s.englishNameTranslation } } : {}),
    };
  });
}

// AlQuran.cloud /meta: data.juzs.references lists where each of the 30 juz
// starts ({surah, ayah}). Returns the juz each surah's first ayah is in.
export function juzOfSurahs(metaJson) {
  const starts = metaJson?.data?.juzs?.references;
  if (!Array.isArray(starts) || starts.length !== 30) throw new Error('Expected 30 juz in metadata');
  const juz = {};
  for (let s = 1; s <= 114; s++) {
    let j = 1;
    starts.forEach((st, i) => {
      if (st.surah < s || (st.surah === s && st.ayah <= 1)) j = i + 1;
    });
    juz[s] = j;
  }
  return juz;
}

// HadeethEnc list items carry the language codes each hadith is translated into.
export function hasAllLanguages(listItem, langs) {
  const codes = listItem.translations ?? [];
  return langs.every((l) => codes.includes(l));
}

// detailByLang: { en: <hadeeths/one response>, so: <...> }
export function buildHadith(detailByLang, extra = {}) {
  const langs = Object.keys(detailByLang);
  const first = detailByLang[langs[0]];
  const out = {
    id: `hadith-${first.id}`,
    hadeethencId: String(first.id),
    ...extra,
    ar: {
      text: first.hadeeth_ar,
      attribution: first.attribution_ar,
      grade: first.grade_ar,
    },
  };
  for (const lang of langs) {
    const d = detailByLang[lang];
    if (String(d.id) !== String(first.id)) {
      throw new Error(`Hadith id mismatch: ${d.id} vs ${first.id}`);
    }
    out[lang] = {
      title: d.title,
      text: d.hadeeth,
      explanation: d.explanation,
      attribution: d.attribution,
      grade: d.grade,
      // HadeethEnc's own short lessons, verbatim.
      hints: Array.isArray(d.hints) ? d.hints.filter((h) => typeof h === 'string' && h.trim()) : [],
    };
  }
  return out;
}

export function buildQuranDua(cfg, rowByLang, translationKeys) {
  const langs = Object.keys(rowByLang);
  const base = rowByLang[langs[0]];
  const meaning = {};
  for (const lang of langs) {
    meaning[lang] = {
      text: rowByLang[lang].translation,
      footnotes: rowByLang[lang].footnotes ?? '',
      source: translationKeys[lang],
    };
  }
  return {
    id: `dua-quran-${cfg.sura}-${cfg.aya}`,
    kind: 'quran',
    moment: cfg.moment,
    key: `${cfg.sura}:${cfg.aya}`,
    arabic: base.arabic_text,
    meaning,
  };
}

// ---------------------------------------------------------------------------
// Mushaf layout
//
// Arabic letters that two Uthmani editions write differently (alif forms,
// hamza seats, alif maqsura) are left out, and so are all marks. What is
// left lines the two texts up letter by letter.
const SKIP_LETTERS = /[اٱأإآءؤئى]/g;
export function skeleton(s) {
  return String(s).replace(/[^ء-ي]/g, '').replace(SKIP_LETTERS, '');
}
export const skeletonLength = (s) => skeleton(s).length;

// Words of an ayah as the app splits them: on spaces.
export const ayahWords = (arabic) => String(arabic).trim().split(/\s+/);

// Places the words of one ayah (our text) on the mushaf lines of the layout.
// layoutRuns: [[page, line, wordCount, letterCount]] in the layout's own
// word positions. Returns runs in our words: [[page, line, wordCount]].
//
// Same number of words: the n-th word goes where the layout puts its n-th
// word. Otherwise each word goes on the line holding the same share of the
// ayah's letters. Marks with no letters (۞, ۩) join the next word, or the
// previous one at the end.
export function placeAyahWords(arabic, layoutRuns) {
  const words = ayahWords(arabic);
  const lettered = words.map((w) => skeletonLength(w) > 0);
  const slots = []; // one entry per layout word: index into layoutRuns
  layoutRuns.forEach((r, i) => { for (let k = 0; k < r[2]; k++) slots.push(i); });
  const realCount = lettered.filter(Boolean).length;
  const runOf = new Array(words.length).fill(-1);

  if (realCount === slots.length) {
    let k = 0;
    words.forEach((_, i) => { if (lettered[i]) runOf[i] = slots[k++]; });
  } else {
    const ourTotal = words.reduce((t, w) => t + skeletonLength(w), 0);
    const theirTotal = layoutRuns.reduce((t, r) => t + r[3], 0);
    const bounds = []; // cumulative letter end of each layout run
    layoutRuns.reduce((t, r) => { bounds.push(t + r[3]); return t + r[3]; }, 0);
    let seen = 0;
    words.forEach((w, i) => {
      if (!lettered[i]) return;
      const len = skeletonLength(w);
      const mid = ((seen + len / 2) / Math.max(1, ourTotal)) * theirTotal;
      seen += len;
      let r = bounds.findIndex((b) => mid <= b);
      if (r < 0) r = layoutRuns.length - 1;
      runOf[i] = r;
    });
  }
  // Letterless marks: next placed word, else previous.
  for (let i = 0; i < words.length; i++) {
    if (runOf[i] >= 0) continue;
    const next = runOf.slice(i + 1).find((r) => r >= 0);
    const prev = runOf.slice(0, i).reverse().find((r) => r >= 0);
    runOf[i] = next ?? prev ?? 0;
  }
  // Never move backwards (keeps reading order if letter shares disagree).
  for (let i = 1; i < runOf.length; i++) runOf[i] = Math.max(runOf[i], runOf[i - 1]);

  const out = [];
  runOf.forEach((r) => {
    const [p, l] = layoutRuns[r];
    const last = out[out.length - 1];
    if (last && last[0] === p && last[1] === l) last[2]++;
    else out.push([p, l, 1]);
  });
  return out;
}

export const encodeRuns = (runs) => runs.map((r) => r.join('.')).join(' ');

// Adds `ml` (mushaf lines, "page.line.words ...") to every ayah and returns
// the bundle's `mushaf` block. Throws if anything does not fit, so a broken
// layout never ships.
export function attachMushaf(surahs, layout) {
  let placed = 0;
  for (const s of surahs) {
    for (const a of s.ayat) {
      const runs = layout.verses[a.key];
      if (!runs) throw new Error(`Mushaf layout has no ${a.key}`);
      const mine = placeAyahWords(a.arabic, runs);
      const words = ayahWords(a.arabic).length;
      if (mine.reduce((t, r) => t + r[2], 0) !== words) throw new Error(`${a.key}: words lost in layout`);
      a.ml = encodeRuns(mine);
      placed++;
    }
  }
  return {
    layout: layout.layout,
    pages: layout.pages,
    linesPerPage: layout.linesPerPage,
    specials: layout.specials,
    source: layout.source,
    placed,
  };
}

// ---------------------------------------------------------------------------
// Hadith references (Bukhari and Muslim numbers)
//
// HadeethEnc names the collections ("Narrated by Muslim", "Agreed upon") but
// not the numbers. We find the number by looking for the Prophet's words
// (the «...» quote) in the Arabic of each collection, and only for the
// collections HadeethEnc itself names.

export function normalizeArabic(s) {
  return String(s)
    .replace(/[ؐ-ًؚ-ٰٟۖ-ۭـ͏]/g, '')
    .replace(/[إأآٱ]/g, 'ا').replace(/ى/g, 'ي').replace(/ة/g, 'ه')
    .replace(/ؤ/g, 'و').replace(/ئ/g, 'ي')
    .replace(/[^ء-ي ]/g, ' ')
    .split(/\s+/).filter(Boolean);
}

export function trigrams(words) {
  const out = new Set();
  for (let i = 0; i + 3 <= words.length; i++) out.add(words.slice(i, i + 3).join(' '));
  return out;
}

// The quoted words, or the whole text when there is no quote.
export function hadithQuote(arabic) {
  const quotes = [...String(arabic).matchAll(/«([^»]+)»/g)].map((m) => m[1]);
  return quotes.length ? quotes.join(' ') : String(arabic);
}

// Which of the two collections HadeethEnc's Arabic attribution names.
export function namedCollections(attributionAr) {
  const a = String(attributionAr);
  const out = [];
  if (/متفق عليه/.test(a) || /البخاري/.test(a)) out.push('bukhari');
  if (/متفق عليه/.test(a) || /مسلم/.test(a)) out.push('muslim');
  return out;
}

// index: [{ number, ref, grams }] for one collection. Returns the best two.
export function bestMatches(quoteGrams, index) {
  const scored = [];
  for (const h of index) {
    let hit = 0;
    for (const g of quoteGrams) if (h.grams.has(g)) hit++;
    if (hit) scored.push({ number: h.number, ref: h.ref, score: hit / quoteGrams.size });
  }
  scored.sort((x, y) => y.score - x.score || x.number - y.number);
  return scored.slice(0, 3);
}

export const REF_MIN_SCORE = 0.8;
export const REF_MIN_GRAMS = 4;

// Decides the reference for one collection. Manual entries (checked by a
// person against sunnah.com) always win; a number of null blocks a match.
export function decideRef({ collection, quoteGrams, candidates, manual }) {
  if (manual && Object.hasOwn(manual, collection)) {
    const n = manual[collection];
    return n == null ? null : { collection, number: n, how: 'checked' };
  }
  const best = candidates[0];
  if (!best || quoteGrams.size < REF_MIN_GRAMS || best.score < REF_MIN_SCORE) return null;
  return { collection, number: best.number, how: 'matched' };
}

// Child-suitability screen for hadith pulled in bulk from a category. A hit
// does not mean the hadith is wrong, only that an adult should pick it by
// hand rather than it arriving automatically in a children's app.
const ADULT_TOPICS = /\b(adulter|fornicat|intercourse|sexual|menstrua|semen|private parts|naked|wine|alcohol|intoxica|lash|flog|stoning|stoned|crucif|suicide|kill(ed|ing|s)?\b|slay|execut|amputat|slave girl|concubine|divorc|wet dream|ritual bath after)/i;
export function needsAdultReview(text) {
  return ADULT_TOPICS.test(String(text));
}

const isBlank = (v) => typeof v !== 'string' || v.trim() === '';

// Returns a list of problems. An empty list means the bundle may ship.
export function validateBundle(bundle, langs) {
  const errors = [];
  if (bundle.schemaVersion !== 1) errors.push('schemaVersion must be 1');
  if (!bundle.surahs?.length) errors.push('no surahs');
  const seenN = new Set();
  if (bundle.reciters) {
    const editions = new Set();
    for (const r of bundle.reciters) {
      if (editions.has(r.edition)) errors.push(`reciter ${r.edition} listed twice`);
      editions.add(r.edition);
      // The app checks the host against its own allow-list as well.
      if (!/^https:\/\/[^/]+\/.+\/\{n\}\.mp3$/.test(r.urlTemplate ?? '')) errors.push(`reciter ${r.edition}: unexpected url ${r.urlTemplate}`);
      if (isBlank(r.reciter)) errors.push(`reciter ${r.edition}: no name`);
    }
    if (bundle.audio && bundle.reciters[0]?.edition !== bundle.audio.edition) errors.push('the first reciter must be the default audio');
  }
  for (const s of bundle.surahs ?? []) {
    if (!s.ayat?.length) errors.push(`${s.id}: no ayat`);
    if (s.ayahCount && s.ayat?.length !== s.ayahCount) errors.push(`${s.id}: ${s.ayat?.length} ayat, expected ${s.ayahCount}`);
    if (s.revelation !== undefined && s.revelation !== 'meccan' && s.revelation !== 'medinan') errors.push(`${s.id}: bad revelation ${s.revelation}`);
    if (s.juz !== undefined && !(Number.isInteger(s.juz) && s.juz >= 1 && s.juz <= 30)) errors.push(`${s.id}: bad juz ${s.juz}`);
    if (bundle.audio) {
      for (const a of s.ayat ?? []) {
        if (!Number.isInteger(a.n) || a.n < 1 || a.n > 6236 || seenN.has(a.n)) errors.push(`${a.key}: bad audio number ${a.n}`);
        seenN.add(a.n);
      }
    }
    for (const a of s.ayat ?? []) {
      if (isBlank(a.arabic)) errors.push(`${a.key}: empty Arabic`);
      for (const l of langs) {
        if (isBlank(a.meaning?.[l]?.text)) errors.push(`${a.key}: empty ${l} meaning`);
        if (!bundle.sources?.[a.meaning?.[l]?.source]) errors.push(`${a.key}: unknown source for ${l}`);
      }
    }
  }
  if (bundle.mushaf) {
    const pages = bundle.mushaf.pages;
    for (const s of bundle.surahs ?? []) {
      for (const a of s.ayat ?? []) {
        const runs = String(a.ml ?? '').split(' ').filter(Boolean).map((r) => r.split('.').map(Number));
        const ok = runs.length > 0 && runs.every(([p, l, c]) =>
          p >= 1 && p <= pages && l >= 1 && l <= (bundle.mushaf.linesPerPage?.[p] ?? 15) && c >= 1);
        if (!ok) errors.push(`${a.key}: bad mushaf lines "${a.ml}"`);
        else if (runs.reduce((t, r) => t + r[2], 0) !== ayahWords(a.arabic).length) errors.push(`${a.key}: mushaf word count`);
      }
    }
  }
  const topicIds = new Set((bundle.shelves ?? []).flatMap((s) => s.topics.map((t) => t.id)));
  for (const s of bundle.shelves ?? []) {
    for (const t of s.topics) {
      for (const l of langs) if (isBlank(t.title?.[l])) errors.push(`topic ${t.id}: no ${l} title`);
    }
  }
  for (const h of bundle.hadith ?? []) {
    if (topicIds.size && !topicIds.has(h.group)) errors.push(`${h.id}: topic ${h.group} is not on a shelf`);
  }
  const checkRefs = (h) => {
    for (const r of h.refs ?? []) {
      if (!['bukhari', 'muslim'].includes(r.collection) || !Number.isInteger(r.number) || r.number < 1) {
        errors.push(`${h.id}: bad reference ${JSON.stringify(r)}`);
      }
      if (!namedCollections(h.ar?.attribution).includes(r.collection)) {
        errors.push(`${h.id}: ${r.collection} number but HadeethEnc does not name ${r.collection}`);
      }
    }
  };
  const checkHadith = (h) => {
    checkRefs(h);
    if (isBlank(h.ar?.text)) errors.push(`${h.id}: empty Arabic`);
    for (const l of langs) {
      for (const f of ['title', 'text', 'attribution', 'grade']) {
        if (isBlank(h[l]?.[f])) errors.push(`${h.id}: empty ${l}.${f}`);
      }
    }
  };
  (bundle.hadith ?? []).forEach(checkHadith);
  for (const d of bundle.duas ?? []) {
    if (d.kind === 'hadith') checkHadith(d);
    else if (d.kind === 'quran') {
      if (isBlank(d.arabic)) errors.push(`${d.id}: empty Arabic`);
      for (const l of langs) if (isBlank(d.meaning?.[l]?.text)) errors.push(`${d.id}: empty ${l} meaning`);
    } else errors.push(`${d.id}: unknown kind ${d.kind}`);
  }
  const ids = [
    ...(bundle.surahs ?? []),
    ...(bundle.hadith ?? []),
    ...(bundle.duas ?? []),
  ].map((x) => x.id);
  const dup = ids.filter((id, i) => ids.indexOf(id) !== i);
  if (dup.length) errors.push(`duplicate ids: ${[...new Set(dup)].join(', ')}`);
  return errors;
}
