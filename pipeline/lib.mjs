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
    return { key: `${surahCfg.number}:${aya}`, aya, arabic: row.arabic_text, meaning };
  });

  ayat.sort((a, b) => a.aya - b.aya);
  return {
    surah: {
      id: `surah-${surahCfg.number}`,
      number: surahCfg.number,
      name: surahCfg.name,
      nameAr: surahCfg.nameAr,
      ayat,
    },
    warnings,
  };
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

const isBlank = (v) => typeof v !== 'string' || v.trim() === '';

// Returns a list of problems. An empty list means the bundle may ship.
export function validateBundle(bundle, langs) {
  const errors = [];
  for (const s of bundle.surahs ?? []) {
    if (!s.ayat?.length) errors.push(`${s.id}: no ayat`);
    for (const a of s.ayat ?? []) {
      if (isBlank(a.arabic)) errors.push(`${a.key}: empty Arabic`);
      for (const l of langs) {
        if (isBlank(a.meaning?.[l]?.text)) errors.push(`${a.key}: empty ${l} meaning`);
        if (!bundle.sources?.[a.meaning?.[l]?.source]) errors.push(`${a.key}: unknown source for ${l}`);
      }
    }
  }
  const checkHadith = (h) => {
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
