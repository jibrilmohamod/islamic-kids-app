// The Madina mushaf as pages of lines, built from the bundle. Line breaks
// come from the layout file (King Fahd Complex 1441H print, via quran-qcf4);
// the words are the bundle's verified Arabic, unchanged.

import 'models.dart';

/// One piece of a mushaf line.
sealed class LinePart {
  const LinePart();
}

/// The decorated band that opens a surah.
class SurahHeader extends LinePart {
  final Surah surah;
  const SurahHeader(this.surah);
}

/// The basmala line before a surah (not before al-Fatiha, where it is ayah 1,
/// nor before at-Tawbah).
class Basmala extends LinePart {
  final int surah;
  const Basmala(this.surah);
}

/// Words [from, to) of one ayah. [endsAyah] puts the ayah's number marker
/// after the last word.
class AyahWords extends LinePart {
  final Surah surah;
  final Ayah ayah;
  final int from;
  final int to;
  const AyahWords(this.surah, this.ayah, this.from, this.to);

  bool get endsAyah => to == ayah.words.length;
  String get text => ayah.words.sublist(from, to).join(' ');
}

class MushafLine {
  final List<LinePart> parts;
  const MushafLine(this.parts);

  bool get isEmpty => parts.isEmpty;
  bool get isWords => parts.isNotEmpty && parts.every((p) => p is AyahWords);
}

class MushafPage {
  final int number;
  final List<MushafLine> lines;
  const MushafPage(this.number, this.lines);

  /// Ayat that start or continue on this page, in order, without repeats.
  List<AyahWords> get ayahParts => [for (final l in lines) ...l.parts.whereType<AyahWords>()];

  List<Ayah> get ayat {
    final seen = <String>{};
    return [for (final p in ayahParts) if (seen.add(p.ayah.key)) p.ayah];
  }

  /// The surah the page belongs to: the first one whose words are here.
  Surah? get surah => ayahParts.isEmpty ? null : ayahParts.first.surah;
}

class MushafBook {
  final List<MushafPage> pages; // pages[0] is page 1
  final Map<String, int> _pageOfAyah;
  final Map<int, int> _firstPageOfSurah;

  MushafBook._(this.pages, this._pageOfAyah, this._firstPageOfSurah);

  int get pageCount => pages.length;
  MushafPage page(int number) => pages[number - 1];

  /// The page where the ayah starts.
  int pageOf(String ayahKey) => _pageOfAyah[ayahKey] ?? 1;
  int firstPageOf(int surah) => _firstPageOfSurah[surah] ?? 1;

  /// Null when the bundle has no layout (older bundles).
  static MushafBook? from(ContentBundle bundle) {
    final info = bundle.mushaf;
    if (info == null || !bundle.hasMushaf) return null;
    final surahs = {for (final s in bundle.surahs) s.number: s};

    // page -> line -> parts
    final grid = List.generate(info.pages, (i) => List.generate(info.linesOn(i + 1), (_) => <LinePart>[]));
    final pageOfAyah = <String, int>{};
    final firstPage = <int, int>{};

    bool fits(int page, int line) => page >= 1 && page <= info.pages && line >= 1 && line <= grid[page - 1].length;

    for (final entry in info.specials.entries) {
      for (final sp in entry.value) {
        final s = surahs[sp.surah];
        if (s == null || !fits(entry.key, sp.line)) return null;
        grid[entry.key - 1][sp.line - 1].add(sp.kind == 'h' ? SurahHeader(s) : Basmala(sp.surah));
        if (sp.kind == 'h') firstPage[sp.surah] = entry.key;
      }
    }
    for (final s in bundle.surahs) {
      for (final a in s.ayat) {
        var w = 0;
        for (final r in a.mushaf) {
          if (!fits(r.page, r.line)) return null;
          grid[r.page - 1][r.line - 1].add(AyahWords(s, a, w, w + r.words));
          w += r.words;
        }
        if (w != a.words.length) return null;
        pageOfAyah[a.key] = a.mushaf.first.page;
        firstPage.putIfAbsent(s.number, () => a.mushaf.first.page);
      }
    }
    final pages = [
      for (var p = 0; p < info.pages; p++) MushafPage(p + 1, [for (final l in grid[p]) MushafLine(l)]),
    ];
    return MushafBook._(pages, pageOfAyah, firstPage);
  }
}

/// Arabic-Indic digits for ayah and page numbers.
String arabicDigits(int n) {
  const d = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}
