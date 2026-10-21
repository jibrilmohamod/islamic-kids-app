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

  /// Where the ayah's words sit in the Madina mushaf: runs of
  /// (page, line, word count), in reading order. Empty for older bundles.
  final List<MushafRun> mushaf;

  const Ayah({
    required this.key,
    required this.aya,
    this.n,
    required this.arabic,
    required this.meaning,
    this.mushaf = const [],
  });

  Meaning? meaningFor(String lang) => _pick(meaning, lang);

  /// The words as the mushaf view and the games split them.
  List<String> get words => arabic.trim().split(RegExp(r'\s+'));

  factory Ayah.fromJson(Map<String, dynamic> j) => Ayah(
        key: _s(j['key']),
        aya: (j['aya'] as num).toInt(),
        n: (j['n'] as num?)?.toInt(),
        arabic: _s(j['arabic']),
        meaning: _meanings(j['meaning']),
        mushaf: parseMushafRuns(_s(j['ml'])),
      );
}

typedef MushafRun = ({int page, int line, int words});

/// "3.1.9 3.2.2" -> two runs. Anything malformed gives an empty list, so
/// the book view is simply not offered for that bundle.
List<MushafRun> parseMushafRuns(String s) {
  if (s.trim().isEmpty) return const [];
  final out = <MushafRun>[];
  for (final part in s.trim().split(' ')) {
    final f = part.split('.').map(int.tryParse).toList();
    if (f.length != 3 || f.any((x) => x == null || x < 1)) return const [];
    out.add((page: f[0]!, line: f[1]!, words: f[2]!));
  }
  return out;
}

class Surah {
  final String id;
  final int number;
  final String name;
  final String nameAr;
  final List<Ayah> ayat;

  /// 'meccan' or 'medinan' (AlQuran.cloud); null in older bundles.
  final String? revelation;

  /// What the name means, by language (English from AlQuran.cloud).
  final Map<String, String> nameMeaning;

  /// The juz (1 to 30) the surah starts in; null in older bundles.
  final int? juz;

  const Surah({
    required this.id,
    required this.number,
    required this.name,
    required this.nameAr,
    required this.ayat,
    this.revelation,
    this.nameMeaning = const {},
    this.juz,
  });

  factory Surah.fromJson(Map<String, dynamic> j) => Surah(
        id: _s(j['id']),
        number: (j['number'] as num).toInt(),
        name: _s(j['name']),
        nameAr: _s(j['nameAr']),
        ayat: ((j['ayat'] as List?) ?? const []).map((a) => Ayah.fromJson(_map(a))).toList(),
        revelation: switch (j['revelation']) { 'meccan' => 'meccan', 'medinan' => 'medinan', _ => null },
        nameMeaning: {
          for (final e in _map(j['nameMeaning']).entries)
            if (e.value is String) e.key: e.value as String,
        },
        juz: j['juz'] is int ? j['juz'] as int : null,
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

/// A hadith's number in Sahih al-Bukhari or Sahih Muslim.
class HadithRef {
  final String collection; // 'bukhari' or 'muslim'
  final int number;

  /// 'checked' (by a person on sunnah.com) or 'matched' (by the pipeline).
  final String how;

  const HadithRef({required this.collection, required this.number, this.how = 'matched'});

  String get short => '${collection == 'bukhari' ? 'Bukhari' : 'Muslim'} $number';
  String get full => '${collection == 'bukhari' ? 'Sahih al-Bukhari' : 'Sahih Muslim'} $number';

  static HadithRef? fromJson(Map<String, dynamic> j) {
    final c = _s(j['collection']);
    final n = (j['number'] as num?)?.toInt();
    if ((c != 'bukhari' && c != 'muslim') || n == null || n < 1) return null;
    return HadithRef(collection: c, number: n, how: _s(j['how']));
  }
}

class Hadith {
  final String id;
  final String hadeethencId;
  final String group;
  final String arabic;
  final Map<String, HadithText> byLang;
  final List<HadithRef> refs;

  const Hadith({
    required this.id,
    required this.hadeethencId,
    required this.group,
    required this.arabic,
    required this.byLang,
    this.refs = const [],
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
        refs: ((j['refs'] as List?) ?? const [])
            .map((r) => HadithRef.fromJson(_map(r)))
            .whereType<HadithRef>()
            .toList(),
      );

  /// The Prophet's own words: the «...» quotes, or the whole text.
  String get quote {
    final q = RegExp('«([^»]+)»').allMatches(arabic).map((m) => m.group(1)!).toList();
    return q.isEmpty ? arabic : q.join(' ');
  }

  /// Short enough to learn by heart in a sitting.
  bool get isShort => quote.trim().split(RegExp(r'\s+')).length <= 12;

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

  /// The reciter's name in Arabic, when the bundle has it.
  final String? reciterAr;
  final String publisher;
  final String terms;

  const AudioInfo({
    required this.urlTemplate,
    required this.edition,
    required this.bitrate,
    required this.reciter,
    this.reciterAr,
    required this.publisher,
    required this.terms,
  });

  factory AudioInfo.fromJson(Map<String, dynamic> j) => AudioInfo(
        urlTemplate: _s(j['urlTemplate']),
        edition: _s(j['edition']),
        bitrate: (j['bitrate'] as num?)?.toInt() ?? 0,
        reciter: _s(j['reciter']),
        reciterAr: j['reciterAr'] is String ? j['reciterAr'] as String : null,
        publisher: _s(j['publisher']),
        terms: _s(j['terms']),
      );

  Uri urlFor(int n) => Uri.parse(urlTemplate.replaceAll('{n}', '$n'));
}

/// A HadeethEnc category shown as one topic on a shelf. The title is
/// HadeethEnc's own category name.
class HadithTopic {
  final String id;
  final Map<String, String> title;
  const HadithTopic({required this.id, required this.title});

  String titleFor(String lang) => title[lang] ?? title[fallbackLang] ?? (title.isEmpty ? id : title.values.first);

  factory HadithTopic.fromJson(Map<String, dynamic> j) => HadithTopic(
        id: _s(j['id']),
        title: _map(j['title']).map((k, v) => MapEntry(k, _s(v))),
      );
}

class HadithShelf {
  final String id;
  final List<HadithTopic> topics;
  const HadithShelf({required this.id, required this.topics});

  factory HadithShelf.fromJson(Map<String, dynamic> j) => HadithShelf(
        id: _s(j['id']),
        topics: ((j['topics'] as List?) ?? const []).map((t) => HadithTopic.fromJson(_map(t))).toList(),
      );
}

/// Page facts of the Madina mushaf layout. Which words go where is on each
/// ayah ([Ayah.mushaf]); this holds the rest.
class MushafInfo {
  final String layout;
  final int pages;
  final Map<int, int> linesPerPage;

  /// page -> [(line, 'h' surah header | 'b' basmala, surah)]
  final Map<int, List<({int line, String kind, int surah})>> specials;

  const MushafInfo({required this.layout, required this.pages, required this.linesPerPage, required this.specials});

  int linesOn(int page) => linesPerPage[page] ?? 15;

  static MushafInfo? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = _map(raw);
    final pages = (j['pages'] as num?)?.toInt() ?? 0;
    if (pages < 1) return null;
    final lines = <int, int>{};
    _map(j['linesPerPage']).forEach((k, v) {
      final p = int.tryParse(k);
      if (p != null && v is num) lines[p] = v.toInt();
    });
    final specials = <int, List<({int line, String kind, int surah})>>{};
    _map(j['specials']).forEach((k, v) {
      final p = int.tryParse(k);
      if (p == null || v is! List) return;
      specials[p] = [
        for (final e in v)
          if (e is List && e.length == 3 && e[0] is num && e[2] is num)
            (line: (e[0] as num).toInt(), kind: _s(e[1]), surah: (e[2] as num).toInt()),
      ];
    });
    return MushafInfo(layout: _s(j['layout']), pages: pages, linesPerPage: lines, specials: specials);
  }
}

class ContentBundle {
  final String version;
  final List<String> languages;
  final List<String> optionalLanguages;
  final Map<String, SourceInfo> sources;
  final AudioInfo? audio;

  /// Reciters a parent can choose from; the first is the default ([audio]).
  /// Bundles from before the choice existed list only [audio].
  final List<AudioInfo> reciters;
  final List<Surah> surahs;
  final List<Hadith> hadith;
  final List<Dua> duas;
  final List<HadithShelf> shelves;
  final MushafInfo? mushaf;

  ContentBundle({
    required this.version,
    required this.languages,
    this.optionalLanguages = const [],
    required this.sources,
    this.audio,
    List<AudioInfo>? reciters,
    required this.surahs,
    required this.hadith,
    required this.duas,
    this.shelves = const [],
    this.mushaf,
  }) : reciters = reciters ?? (audio == null ? const [] : [audio]);

  /// The book view needs the layout and every ayah placed in it.
  bool get hasMushaf => mushaf != null && surahs.length == 114 && surahs.every((s) => s.ayat.every((a) => a.mushaf.isNotEmpty));

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
      reciters: j['reciters'] is List && (j['reciters'] as List).isNotEmpty
          ? list('reciters').map(AudioInfo.fromJson).toList()
          : null,
      surahs: list('surahs').map(Surah.fromJson).toList(),
      hadith: list('hadith').map((h) => Hadith.fromJson(h, langs)).toList(),
      duas: list('duas').map((d) => Dua.fromJson(d, langs)).toList(),
      shelves: list('shelves').map(HadithShelf.fromJson).toList(),
      mushaf: MushafInfo.fromJson(j['mushaf']),
    );
  }

  SourceInfo? source(String key) => sources[key];
}
