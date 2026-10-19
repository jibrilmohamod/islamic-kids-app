// Run: node --test pipeline/
// Fixtures use dummy strings shaped like the real API responses (field names
// checked against the live QuranEnc and HadeethEnc APIs on 2026-10-19).
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  extractList, findTranslationMeta, buildSurah, hasAllLanguages, buildHadith,
  validateBundle, surahConfigsFromMeta, placeAyahWords, attachMushaf, skeleton,
  normalizeArabic, trigrams, hadithQuote, namedCollections, bestMatches, decideRef, needsAdultReview,
} from './lib.mjs';
import { readFileSync } from 'node:fs';
import { build } from './build-bundle.mjs';

const ayaRow = (sura, aya, lang) => ({
  id: String(sura * 1000 + aya), sura: String(sura), aya: String(aya),
  arabic_text: `AR-${sura}-${aya}`, translation: `${lang.toUpperCase()}-${sura}-${aya}`, footnotes: '',
});

const hadithDetail = (id, lang) => ({
  id: String(id), title: `${lang} title ${id}`, hadeeth: `${lang} text ${id}`,
  attribution: `${lang} attribution`, grade: `${lang} grade`, explanation: `${lang} explanation`,
  hints: [`${lang} lesson`, ''], categories: ['301'], translations: ['ar', 'en', 'so'],
  hadeeth_ar: `AR hadith ${id}`, attribution_ar: 'AR attribution', grade_ar: 'AR grade',
});

test('extractList accepts the shapes QuranEnc might return', () => {
  assert.deepEqual(extractList([1]), [1]);
  assert.deepEqual(extractList({ result: [2] }), [2]);
  assert.deepEqual(extractList({ anything: [3] }), [3]);
  assert.throws(() => extractList({ a: 1 }));
});

test('findTranslationMeta finds by key', () => {
  const list = { translations: [{ key: 'somali_yacob', version: '1.0.26', title: 'Somali' }] };
  assert.equal(findTranslationMeta(list, 'somali_yacob').version, '1.0.26');
  assert.throws(() => findTranslationMeta(list, 'missing'));
});

test('buildSurah keeps text verbatim and sorts ayat', () => {
  const rows = { en: [ayaRow(105, 2, 'en'), ayaRow(105, 1, 'en')], so: [ayaRow(105, 1, 'so'), ayaRow(105, 2, 'so')] };
  const { surah, warnings } = buildSurah({ number: 105, name: 'Al-Fil', nameAr: 'الفيل' }, rows, { en: 'english_saheeh', so: 'somali_yacob' });
  assert.equal(surah.ayat[0].key, '105:1');
  assert.equal(surah.ayat[0].meaning.so.text, 'SO-105-1');
  assert.equal(surah.ayat[1].arabic, 'AR-105-2');
  assert.deepEqual(warnings, []);
});

test('buildSurah fails when a language is missing an ayah', () => {
  const rows = { en: [ayaRow(1, 1, 'en'), ayaRow(1, 2, 'en')], so: [ayaRow(1, 1, 'so')] };
  assert.throws(() => buildSurah({ number: 1 }, rows, { en: 'e', so: 's' }), /1:2 missing in so/);
});

test('hasAllLanguages', () => {
  assert.equal(hasAllLanguages({ translations: ['en', 'so', 'ar'] }, ['en', 'so']), true);
  assert.equal(hasAllLanguages({ translations: ['en'] }, ['en', 'so']), false);
});

test('buildHadith maps fields per language', () => {
  const h = buildHadith({ en: hadithDetail(9, 'en'), so: hadithDetail(9, 'so') }, { group: 'g' });
  assert.equal(h.id, 'hadith-9');
  assert.equal(h.so.text, 'so text 9');
  assert.equal(h.ar.text, 'AR hadith 9');
  assert.equal(h.group, 'g');
  assert.deepEqual(h.so.hints, ['so lesson']);
});

test('validateBundle catches empty text and duplicate ids', () => {
  const bundle = {
    schemaVersion: 1,
    sources: { e: {}, s: {} },
    surahs: [{ id: 'surah-1', ayat: [{ key: '1:1', arabic: 'x', meaning: { en: { text: '', source: 'e' }, so: { text: 'y', source: 's' } } }] }],
    hadith: [{ id: 'dup', ar: { text: 'a' }, en: { title: 't', text: 't', attribution: 'a', grade: 'g' }, so: { title: 't', text: 't', attribution: 'a', grade: 'g' } }],
    duas: [{ id: 'dup', kind: 'quran', arabic: 'a', meaning: { en: { text: 'x' }, so: { text: 'y' } } }],
  };
  const errors = validateBundle(bundle, ['en', 'so']);
  assert.ok(errors.some((e) => e.includes('1:1: empty en meaning')));
  assert.ok(errors.some((e) => e.includes('duplicate ids: dup')));
});

test('full build against a fake API', async () => {
  const config = {
    languages: ['en', 'so'],
    quranTranslations: { en: 'english_saheeh', so: 'somali_yacob' },
    surahs: [{ number: 112, name: 'Al-Ikhlas', nameAr: 'الإخلاص' }],
    hadithShelves: [{ id: 'manners', topics: [{ id: 'manners-eating', categoryId: 290, max: 1 }] }],
    duaCategories: [{ moment: 'home', categoryId: 303 }],
    quranDuas: [{ moment: 'anytime', sura: 20, aya: 114 }],
  };
  const fake = async (url) => {
    if (url.includes('/translations/list/en')) return { translations: [{ key: 'english_saheeh', version: '1.1.2', title: 'EN' }] };
    if (url.includes('/translations/list/so')) return { translations: [{ key: 'somali_yacob', version: '1.0.26', title: 'SO' }] };
    let m = url.match(/translation\/sura\/(\w+)\/(\d+)/);
    if (m) {
      const lang = m[1].startsWith('english') ? 'en' : 'so';
      return { result: [1, 2, 3, 4].map((a) => ayaRow(Number(m[2]), a, lang)) };
    }
    m = url.match(/translation\/aya\/(\w+)\/(\d+)\/(\d+)/);
    if (m) return { result: ayaRow(Number(m[2]), Number(m[3]), m[1].startsWith('english') ? 'en' : 'so') };
    if (url.includes('categories/list')) return [{ id: '290', title: 'Manners of Eating' }];
    if (url.includes('category_id=290')) return { data: [{ id: '11', translations: ['en'] }, { id: '12', translations: ['en', 'so'] }], meta: { last_page: 1 } };
    if (url.includes('category_id=303')) return { data: [{ id: '21', translations: ['en', 'so'] }], meta: { last_page: 1 } };
    m = url.match(/hadeeths\/one\/\?id=(\d+)&language=(\w+)/);
    if (m) return hadithDetail(m[1], m[2]);
    throw new Error(`unexpected url ${url}`);
  };
  const { bundle, errors } = await build(config, fake, () => {});
  assert.deepEqual(errors, []);
  assert.equal(bundle.surahs[0].ayat.length, 4);
  assert.equal(bundle.hadith.length, 1);
  assert.equal(bundle.hadith[0].hadeethencId, '12');
  assert.equal(bundle.duas.length, 2);
  assert.equal(bundle.duas[0].id, 'dua-hadith-21');
  assert.equal(bundle.duas[1].meaning.so.text, 'SO-20-114');
  assert.equal(bundle.sources.somali_yacob.version, '1.0.26');
});

test('optional language is added where available and never required', async () => {
  const config = {
    languages: ['en'],
    optionalLanguages: ['so'],
    quranTranslations: { en: 'english_saheeh', so: 'somali_yacob' },
    surahs: [{ number: 112, name: 'Al-Ikhlas', nameAr: 'الإخلاص' }],
    hadithShelves: [{ id: 's', topics: [{ id: 'g', categoryId: 290, max: 5 }] }],
    duaCategories: [],
    quranDuas: [],
  };
  const fake = async (url) => {
    if (url.includes('/translations/list/en')) return { translations: [{ key: 'english_saheeh', version: '1', title: 'EN' }] };
    if (url.includes('/translations/list/so')) return { translations: [{ key: 'somali_yacob', version: '2', title: 'SO' }] };
    const sm = url.match(/translation\/sura\/(\w+)\/(\d+)/);
    if (sm) return { result: [1, 2].map((a) => ayaRow(Number(sm[2]), a, sm[1].startsWith('english') ? 'en' : 'so')) };
    if (url.includes('categories/list/?language=en')) return [{ id: 290, title: 'Eating' }];
    if (url.includes('categories/list/?language=so')) throw new Error('HTTP 404');
    if (url.includes('category_id=290')) return { data: [{ id: '11', translations: ['en'] }, { id: '12', translations: ['en', 'so'] }, { id: '13', translations: ['so'] }], meta: { last_page: 1 } };
    const m = url.match(/hadeeths\/one\/\?id=(\d+)&language=(\w+)/);
    if (m) return hadithDetail(m[1], m[2]);
    throw new Error(`unexpected url ${url}`);
  };
  const { bundle, errors } = await build(config, fake, () => {});
  assert.deepEqual(errors, []);
  assert.deepEqual(bundle.hadith.map((h) => h.hadeethencId), ['11', '12']);
  assert.equal(bundle.hadith[0].so, undefined);
  assert.equal(bundle.hadith[1].so.text, 'so text 12');
  assert.deepEqual(bundle.optionalLanguages, ['so']);
});

test('surah metadata gives 114 configs with short Arabic names', () => {
  const data = Array.from({ length: 114 }, (_, i) => ({
    number: i + 1, name: 'سُورَةُ ٱلۡفَاتِحَةِ', englishName: `S${i + 1}`, numberOfAyahs: 7,
  }));
  const cfgs = surahConfigsFromMeta({ data });
  assert.equal(cfgs.length, 114);
  assert.equal(cfgs[0].nameAr, 'ٱلۡفَاتِحَةِ');
  assert.equal(cfgs[113].ayahCount, 7);
  assert.throws(() => surahConfigsFromMeta({ data: data.slice(1) }));
});

test('audio picks the first bitrate that answers and every ayah gets its number', async () => {
  const config = {
    languages: ['en'],
    quranTranslations: { en: 'english_saheeh' },
    surahs: [{ number: 1, name: 'Al-Fatiha', nameAr: 'x', ayahCount: 2 }],
    audio: { edition: 'ar.alafasy', bitrates: [64, 128], base: 'https://cdn.example/quran/audio', reciter: 'R', publisher: 'P', terms: 'T' },
    duaCategories: [], quranDuas: [],
  };
  const fake = async (url) => {
    if (url.includes('/translations/list/en')) return { translations: [{ key: 'english_saheeh', version: '1', title: 'EN' }] };
    if (url.includes('translation/sura/english_saheeh/1')) return { result: [1, 2].map((a) => ({ id: String(a), sura: '1', aya: String(a), arabic_text: `A${a}`, translation: `E${a}`, footnotes: '' })) };
    throw new Error(`unexpected url ${url}`);
  };
  const tried = [];
  const head = async (url) => { tried.push(url); return url.includes('/128/'); };
  const { bundle, errors } = await build(config, fake, () => {}, head);
  assert.deepEqual(errors, []);
  assert.equal(bundle.audio.bitrate, 128);
  assert.equal(bundle.audio.urlTemplate, 'https://cdn.example/quran/audio/128/ar.alafasy/{n}.mp3');
  assert.equal(tried.length, 2);
  assert.deepEqual(bundle.surahs[0].ayat.map((a) => a.n), [1, 2]);
  assert.equal(bundle.surahs[0].ayahCount, 2);
});

test('the full build adds topic titles, references and held-back hadith', async () => {
  const quote = 'إِنَّ اللهَ لَيَرْضَى عَنِ الْعَبْدِ أَنْ يَأْكُلَ الْأَكْلَةَ فَيَحْمَدَهُ عَلَيْهَا';
  const config = {
    languages: ['en'],
    quranTranslations: { en: 'english_saheeh' },
    surahs: [{ number: 112, name: 'Al-Ikhlas', nameAr: 'x' }],
    hadithShelves: [{ id: 'manners', topics: [{ id: 'manners-eating', categoryId: 290, max: 5 }] }],
    duaCategories: [], quranDuas: [],
    hadithRefs: { publisher: 'P', title: 'T', url: 'U', version: 'v', base: 'https://raw.example/editions', editions: { muslim: 'ara-muslim1' } },
  };
  const detail = (id) => ({
    ...hadithDetail(id, 'en'),
    hadeeth: id === '2' ? 'Every drink that intoxicates is unlawful.' : 'en text',
    hadeeth_ar: `قال: «${quote}».`, attribution_ar: 'رواه مسلم',
  });
  const fake = async (url) => {
    if (url.includes('/translations/list/en')) return { translations: [{ key: 'english_saheeh', version: '1', title: 'EN' }] };
    if (url.includes('translation/sura/')) return { result: [ayaRow(112, 1, 'en')] };
    if (url.includes('categories/list')) return [{ id: 290, title: 'Manners of Eating and Drinking' }];
    if (url.includes('category_id=290')) return { data: [{ id: '1', translations: ['en'] }, { id: '2', translations: ['en'] }], meta: { last_page: 1 } };
    const m = url.match(/hadeeths\/one\/\?id=(\d+)/);
    if (m) return detail(m[1]);
    if (url === 'https://raw.example/editions/ara-muslim1.min.json') {
      return { hadiths: [{ hadithnumber: 6932, arabicnumber: '2734.01', text: `حدثنا ... ${quote}` }, { hadithnumber: 1, arabicnumber: 1, text: 'نص آخر تماما هنا' }] };
    }
    throw new Error(`unexpected url ${url}`);
  };
  const { bundle, errors, report } = await build(config, fake, () => {});
  assert.deepEqual(errors, []);
  assert.deepEqual(bundle.hadith.map((h) => h.hadeethencId), ['1']);
  assert.deepEqual(bundle.hadith[0].refs, [{ collection: 'muslim', number: 2734, how: 'matched' }]);
  assert.equal(bundle.shelves[0].topics[0].title.en, 'Manners of Eating and Drinking');
  assert.deepEqual(report.heldBack.map((h) => h.id), ['2']);
});

test('placeAyahWords: same word count maps word by word', () => {
  const runs = placeAyahWords('أ ب ت ث', [[3, 1, 3, 3], [3, 2, 1, 1]]);
  assert.deepEqual(runs, [[3, 1, 3], [3, 2, 1]]);
});

test('placeAyahWords: a word the layout splits in two, and marks without letters', () => {
  // Our text: ۞ + "لوما" (one word) + "تاتينا"; layout: "لو" "ما" on line 8, "تاتينا" on line 9.
  const runs = placeAyahWords('۞ لَوۡمَا تَأۡتِينَا', [[262, 8, 2, 3], [262, 9, 1, 4]]);
  assert.deepEqual(runs, [[262, 8, 2], [262, 9, 1]]);
});

test('placeAyahWords: the sajda sign the layout counts as its own word', () => {
  const runs = placeAyahWords('وَلَهُۥ يَسۡجُدُونَۤ۩', [[176, 14, 1, 3], [176, 15, 2, 6]]);
  assert.deepEqual(runs, [[176, 14, 1], [176, 15, 1]]);
});

test('skeleton ignores alif forms, hamza seats and marks', () => {
  assert.equal(skeleton('ٱلۡمَلَٰٓئِكَةِ'), skeleton('الْمَلَائِكَةِ'));
});

test('the committed mushaf layout places every ayah of the committed bundle', () => {
  const layout = JSON.parse(readFileSync(new URL('./data/madina-1441h-layout.json', import.meta.url), 'utf8'));
  const bundle = JSON.parse(readFileSync(new URL('../app/assets/content/bundle.json', import.meta.url), 'utf8'));
  const m = attachMushaf(bundle.surahs, layout);
  assert.equal(m.placed, 6236);
  const a26 = bundle.surahs[1].ayat[25];
  assert.equal(a26.key, '2:26');
  assert.ok(a26.ml.startsWith('5.4.'));
  assert.equal(bundle.surahs[113].ayat[5].ml, '604.15.3');
});

test('reference helpers', () => {
  assert.deepEqual(namedCollections('متفق عليه'), ['bukhari', 'muslim']);
  assert.deepEqual(namedCollections('رواه البخاري'), ['bukhari']);
  assert.deepEqual(namedCollections('رواه مسلم'), ['muslim']);
  assert.deepEqual(namedCollections('رواه أبو داود والترمذي'), []);
  assert.equal(hadithQuote('عن أنس قال: «قول النبي» وقال «ثان»'), 'قول النبي ثان');
  assert.deepEqual(normalizeArabic('إِنَّ ٱللَّهَ'), ['ان', 'الله']);
  const q = trigrams(normalizeArabic('ا ب ت ث ج'));
  const idx = [{ number: 5, grams: trigrams(normalizeArabic('س ا ب ت ث ج')) }, { number: 9, grams: trigrams(normalizeArabic('ا ب ت')) }];
  const c = bestMatches(q, idx);
  assert.equal(c[0].number, 5);
  assert.equal(c[0].score, 1);
});

test('decideRef: checked numbers win, weak matches are dropped', () => {
  const big = new Set(['a', 'b', 'c', 'd', 'e']);
  const strong = [{ number: 10, score: 0.9 }];
  const weak = [{ number: 11, score: 0.6 }];
  assert.deepEqual(decideRef({ collection: 'muslim', quoteGrams: big, candidates: strong }), { collection: 'muslim', number: 10, how: 'matched' });
  assert.equal(decideRef({ collection: 'muslim', quoteGrams: big, candidates: weak }), null);
  assert.equal(decideRef({ collection: 'muslim', quoteGrams: new Set(['a']), candidates: strong }), null);
  assert.deepEqual(decideRef({ collection: 'muslim', quoteGrams: big, candidates: weak, manual: { muslim: 2021 } }), { collection: 'muslim', number: 2021, how: 'checked' });
  assert.equal(decideRef({ collection: 'muslim', quoteGrams: big, candidates: strong, manual: { muslim: null } }), null);
});

test('needsAdultReview flags adult topics only', () => {
  assert.equal(needsAdultReview('Every drink that intoxicates is unlawful.'), true);
  assert.equal(needsAdultReview('Eat with your right hand.'), false);
  assert.equal(needsAdultReview('He was killed in battle.'), true);
  assert.equal(needsAdultReview('He loved the skill of archery.'), false);
});

test('validateBundle rejects a number from a collection HadeethEnc does not name', () => {
  const h = { id: 'hadith-1', group: 'g', ar: { text: 'a', attribution: 'رواه مسلم' }, refs: [{ collection: 'bukhari', number: 5 }],
    en: { title: 't', text: 't', attribution: 'a', grade: 'g' } };
  const errors = validateBundle({ schemaVersion: 1, sources: {}, surahs: [{ id: 's', ayat: [] }], hadith: [h], duas: [] }, ['en']);
  assert.ok(errors.some((e) => e.includes('does not name bukhari')));
});

// #21: HadeethEnc lists a Somali translation that its detail endpoint does
// not serve (hadeeths/one/?id=66520&language=so answered HTTP 404 on
// 2026-10-19). An optional language must never sink the build.
test('a missing optional-language hadith is skipped, not fatal', async () => {
  const config = {
    languages: ['en'],
    optionalLanguages: ['so'],
    quranTranslations: { en: 'english_saheeh', so: 'somali_yacob' },
    surahs: [{ number: 112, name: 'Al-Ikhlas', nameAr: 'x' }],
    hadithShelves: [{ id: 's', topics: [{ id: 's-a', categoryId: 290, max: 5 }] }],
    duaCategories: [], quranDuas: [],
  };
  const warned = [];
  const fake = async (url) => {
    if (url.includes('/translations/list/en')) return { translations: [{ key: 'english_saheeh', version: '1', title: 'EN' }] };
    if (url.includes('/translations/list/so')) return { translations: [{ key: 'somali_yacob', version: '2', title: 'SO' }] };
    const sm = url.match(/translation\/sura\/(\w+)\/(\d+)/);
    if (sm) return { result: [ayaRow(112, 1, sm[1].startsWith('english') ? 'en' : 'so')] };
    if (url.includes('categories/list')) return [{ id: 290, title: 'Eating' }];
    if (url.includes('category_id=290')) return { data: [{ id: '66520', translations: ['en', 'so'] }], meta: { last_page: 1 } };
    if (url.includes('id=66520&language=so')) throw new Error(`${url}: HTTP 404`);
    const m = url.match(/hadeeths\/one\/\?id=(\d+)&language=(\w+)/);
    if (m) return hadithDetail(m[1], m[2]);
    throw new Error(`unexpected url ${url}`);
  };
  const { bundle, errors, warnings } = await build(config, fake, (l) => warned.push(l));
  assert.deepEqual(errors, []);
  assert.equal(bundle.hadith.length, 1);
  assert.equal(bundle.hadith[0].en.text, 'en text 66520');
  assert.equal(bundle.hadith[0].so, undefined);
  assert.ok(warnings.some((w) => w.includes('66520') && w.includes('so')));
});

test('a missing required-language hadith still fails the build', async () => {
  const config = {
    languages: ['en'],
    quranTranslations: { en: 'english_saheeh' },
    surahs: [{ number: 112, name: 'Al-Ikhlas', nameAr: 'x' }],
    hadithShelves: [{ id: 's', topics: [{ id: 's-a', categoryId: 290, max: 5 }] }],
    duaCategories: [], quranDuas: [],
  };
  const fake = async (url) => {
    if (url.includes('/translations/list/en')) return { translations: [{ key: 'english_saheeh', version: '1', title: 'EN' }] };
    if (url.includes('translation/sura/')) return { result: [ayaRow(112, 1, 'en')] };
    if (url.includes('categories/list')) return [{ id: 290, title: 'Eating' }];
    if (url.includes('category_id=290')) return { data: [{ id: '7', translations: ['en'] }], meta: { last_page: 1 } };
    if (url.includes('hadeeths/one/')) throw new Error(`${url}: HTTP 404`);
    throw new Error(`unexpected url ${url}`);
  };
  await assert.rejects(build(config, fake, () => {}), /HTTP 404/);
});
