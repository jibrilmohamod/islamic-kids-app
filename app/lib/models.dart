// Data classes for the content bundle written by pipeline/build-bundle.mjs.
// Religious text here is always verbatim from the source APIs.

String _s(Object? v) => v == null ? '' : v.toString();

/// Reads any JSON object as Map<String, dynamic>, or an empty map.
Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : <String, dynamic>{};

class SourceInfo {
  final String key;
  final String publisher;
  final String title;
  final String version;
  final String url;

  const SourceInfo({
    required this.key,
    required this.publisher,
    required this.title,
    required this.version,
    required this.url,
  });

  factory SourceInfo.fromJson(String key, Map<String, dynamic> j) => SourceInfo(
        key: key,
        publisher: _s(j['publisher']),
        title: _s(j['title']),
        version: _s(j['version']),
        url: _s(j['url']),
      );

  String get label {
    final v = version.isEmpty ? '' : ' · v$version';
    return '$publisher · $title$v';
  }
}

class Meaning {
  final String text;
  final String footnotes;
  final String source;

  const Meaning({required this.text, required this.footnotes, required this.source});

  factory Meaning.fromJson(Map<String, dynamic> j) => Meaning(
        text: _s(j['text']),
        footnotes: _s(j['footnotes']),
        source: _s(j['source']),
      );
}

/// The language used when an item has no text in the chosen language.
const fallbackLang = 'en';

Meaning? _pick(Map<String, Meaning> m, String lang) =>
    m[lang] ?? m[fallbackLang] ?? (m.isEmpty ? null : m.values.first);

Map<String, Meaning> _meanings(Object? raw) {
  return _map(raw).map((k, v) => MapEntry(k, Meaning.fromJson(_map(v))));
}

class Ayah {
  final String key;
  final int aya;

  /// Position in the whole Quran (1 to 6236); names the audio file.
  final int? n;
  final String arabic;
  final Map<String, Meaning> meaning;

  const Ayah({required this.key, required this.aya, this.n, required this.arabic, required this.meaning});

  Meaning? meaningFor(String lang) => _pick(meaning, lang);

  factory Ayah.fromJson(Map<String, dynamic> j) => Ayah(
        key: _s(j['key']),
        aya: (j['aya'] as num).toInt(),
        n: (j['n'] as num?)?.toInt(),
        arabic: _s(j['arabic']),
        meaning: _meanings(j['meaning']),
      );
}

class Surah {
  final String id;
  final int number;
  final String name;
  final String nameAr;
  final List<Ayah> ayat;

  const Surah({
    required this.id,
    required this.number,
    required this.name,
    required this.nameAr,
    required this.ayat,
  });

  factory Surah.fromJson(Map<String, dynamic> j) => Surah(
        id: _s(j['id']),
        number: (j['number'] as num).toInt(),
        name: _s(j['name']),
        nameAr: _s(j['nameAr']),
        ayat: ((j['ayat'] as List?) ?? const []).map((a) => Ayah.fromJson(_map(a))).toList(),
      );
}

class HadithText {
  final String title;
  final String text;
  final String explanation;
  final String attribution;
  final String grade;

  /// HadeethEnc's own short lessons, verbatim.
  final List<String> hints;

  const HadithText({
    required this.title,
    required this.text,
    required this.explanation,
    required this.attribution,
    required this.grade,
    this.hints = const [],
  });

  factory HadithText.fromJson(Map<String, dynamic> j) => HadithText(
        title: _s(j['title']),
        text: _s(j['text']),
        explanation: _s(j['explanation']),
        attribution: _s(j['attribution']),
        grade: _s(j['grade']),
        hints: ((j['hints'] as List?) ?? const []).map(_s).where((h) => h.isNotEmpty).toList(),
      );
}

class Hadith {
  final String id;
  final String hadeethencId;
  final String group;
  final String arabic;
  final Map<String, HadithText> byLang;

  const Hadith({
    required this.id,
    required this.hadeethencId,
    required this.group,
    required this.arabic,
    required this.byLang,
  });

  factory Hadith.fromJson(Map<String, dynamic> j, List<String> langs) => Hadith(
        id: _s(j['id']),
        hadeethencId: _s(j['hadeethencId']),
        group: _s(j['group']),
        arabic: _s(_map(j['ar'])['text']),
        byLang: {
          for (final l in langs)
            if (j[l] is Map) l: HadithText.fromJson(_map(j[l])),
        },
      );

  bool has(String lang) => byLang.containsKey(lang);

  HadithText t(String lang) =>
      byLang[lang] ?? byLang[fallbackLang] ?? byLang.values.first;
}

/// A dua is either a hadith from HadeethEnc or a Quranic ayah from QuranEnc.
class Dua {
  final String id;
  final String moment;
  final Hadith? hadith;
  final String? quranKey;
  final String arabic;
  final Map<String, Meaning> meaning;

  const Dua({
    required this.id,
    required this.moment,
    required this.arabic,
    this.hadith,
    this.quranKey,
    this.meaning = const {},
  });

  bool get isQuran => quranKey != null;

  Meaning? meaningFor(String lang) => _pick(meaning, lang);

  factory Dua.fromJson(Map<String, dynamic> j, List<String> langs) {
    if (j['kind'] == 'quran') {
      return Dua(
        id: _s(j['id']),
        moment: _s(j['moment']),
        quranKey: _s(j['key']),
        arabic: _s(j['arabic']),
        meaning: _meanings(j['meaning']),
      );
    }
    final h = Hadith.fromJson(j, langs);
    return Dua(id: h.id, moment: _s(j['moment']), hadith: h, arabic: h.arabic);
  }
}

/// Where per-ayah recitation audio comes from, and whose it is.
class AudioInfo {
  final String urlTemplate;
  final String edition;
  final int bitrate;
  final String reciter;
  final String publisher;
  final String terms;

  const AudioInfo({
    required this.urlTemplate,
    required this.edition,
    required this.bitrate,
    required this.reciter,
    required this.publisher,
    required this.terms,
  });

  factory AudioInfo.fromJson(Map<String, dynamic> j) => AudioInfo(
        urlTemplate: _s(j['urlTemplate']),
        edition: _s(j['edition']),
        bitrate: (j['bitrate'] as num?)?.toInt() ?? 0,
        reciter: _s(j['reciter']),
        publisher: _s(j['publisher']),
        terms: _s(j['terms']),
      );

  Uri urlFor(int n) => Uri.parse(urlTemplate.replaceAll('{n}', '$n'));
}

class ContentBundle {
  final String version;
  final List<String> languages;
  final List<String> optionalLanguages;
  final Map<String, SourceInfo> sources;
  final AudioInfo? audio;
  final List<Surah> surahs;
  final List<Hadith> hadith;
  final List<Dua> duas;

  const ContentBundle({
    required this.version,
    required this.languages,
    this.optionalLanguages = const [],
    required this.sources,
    this.audio,
    required this.surahs,
    required this.hadith,
    required this.duas,
  });

  factory ContentBundle.fromJson(Map<String, dynamic> j) {
    final required = ((j['languages'] as List?) ?? const ['en']).map((e) => e.toString()).toList();
    final optional = ((j['optionalLanguages'] as List?) ?? const []).map((e) => e.toString()).toList();
    final langs = [...required, ...optional];
    List<Map<String, dynamic>> list(String k) =>
        ((j[k] as List?) ?? const []).map(_map).toList();
    return ContentBundle(
      version: _s(j['bundleVersion']),
      languages: required,
      optionalLanguages: optional,
      sources: _map(j['sources']).map((k, v) => MapEntry(k, SourceInfo.fromJson(k, _map(v)))),
      audio: j['audio'] is Map ? AudioInfo.fromJson(_map(j['audio'])) : null,
      surahs: list('surahs').map(Surah.fromJson).toList(),
      hadith: list('hadith').map((h) => Hadith.fromJson(h, langs)).toList(),
      duas: list('duas').map((d) => Dua.fromJson(d, langs)).toList(),
    );
  }

  SourceInfo? source(String key) => sources[key];
}
