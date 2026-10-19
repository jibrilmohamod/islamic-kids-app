// Run: flutter test
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/models.dart';
import 'package:islamic_kids_app/mushaf.dart';
import 'package:islamic_kids_app/screens/downloads_screen.dart';

/// A two-page book: surah 1 (header + 2 ayat) on page 1, surah 2 starting
/// on page 2 with a basmala.
ContentBundle tinyBook() {
  Map<String, Object?> ayah(int s, int a, int n, String arabic, String ml) =>
      {'key': '$s:$a', 'aya': a, 'n': n, 'arabic': arabic, 'meaning': {}, 'ml': ml};
  final j = {
    'bundleVersion': 't',
    'languages': ['en'],
    'sources': {},
    'mushaf': {
      'layout': 'test',
      'pages': 2,
      'linesPerPage': {'1': 3, '2': 3},
      'specials': {
        '1': [[1, 'h', 1]],
        '2': [[1, 'h', 2], [2, 'b', 2]],
      },
    },
    'surahs': [
      {'id': 'surah-1', 'number': 1, 'name': 'One', 'nameAr': 'و', 'ayat': [ayah(1, 1, 1, 'ا ب ت', '1.2.3'), ayah(1, 2, 2, 'ث ج ح خ', '1.2.1 1.3.3')]},
      {'id': 'surah-2', 'number': 2, 'name': 'Two', 'nameAr': 'ث', 'ayat': [ayah(2, 1, 3, 'د ذ', '2.3.2')]},
    ],
    'hadith': [],
    'duas': [],
  };
  return ContentBundle.fromJson(j);
}

void main() {
  test('mushaf runs parse, and bad ones give nothing', () {
    expect(parseMushafRuns('3.1.9 3.2.2'), [(page: 3, line: 1, words: 9), (page: 3, line: 2, words: 2)]);
    expect(parseMushafRuns(''), isEmpty);
    expect(parseMushafRuns('3.1'), isEmpty);
    expect(parseMushafRuns('3.0.2'), isEmpty);
  });

  test('a book needs every surah placed', () {
    // Only 2 surahs in the tiny bundle, so hasMushaf is false and no book.
    expect(tinyBook().hasMushaf, isFalse);
    expect(MushafBook.from(tinyBook()), isNull);
  });

  test('arabic digits', () {
    expect(arabicDigits(255), '٢٥٥');
    expect(arabicDigits(7), '٧');
  });

  test('saved surahs group files and skip empty ones', () {
    final b = tinyBook();
    final list = savedSurahs(b.surahs, {1: 1000, 2: 2000});
    expect(list.length, 1);
    expect(list.first.complete, isTrue);
    expect(list.first.bytes, 3000);
    final half = savedSurahs(b.surahs, {2: 10, 3: 5});
    expect(half.map((x) => (x.surah.number, x.saved, x.complete)), [(1, 1, false), (2, 1, true)]);
    expect(megabytes(5 * 1024 * 1024), '5.0');
    expect(megabytes(42 * 1024 * 1024), '42');
  });

  test('hadith references and short hadith', () {
    final h = Hadith.fromJson({
      'id': 'hadith-1',
      'group': 'manners-eating',
      'ar': {'text': 'عن أنس قال: «إِنَّ اللهَ لَيَرْضَى»'},
      'refs': [
        {'collection': 'muslim', 'number': 2734, 'how': 'matched'},
        {'collection': 'tirmidhi', 'number': 5},
        {'collection': 'bukhari', 'number': 0},
      ],
      'en': {'title': 't', 'text': 't', 'attribution': 'a', 'grade': 'g'},
    }, ['en']);
    expect(h.refs.map((r) => r.full), ['Sahih Muslim 2734']);
    expect(h.refs.first.short, 'Muslim 2734');
    expect(h.quote, 'إِنَّ اللهَ لَيَرْضَى');
    expect(h.isShort, isTrue);
  });

  test('shelves and topic titles read from the bundle', () {
    final b = ContentBundle.fromJson({
      'bundleVersion': 't',
      'languages': ['en'],
      'sources': {},
      'surahs': [],
      'hadith': [],
      'duas': [],
      'shelves': [
        {
          'id': 'manners',
          'topics': [
            {'id': 'manners-eating', 'categoryId': 290, 'title': {'en': 'Manners of Eating and Drinking'}},
          ],
        },
      ],
    });
    expect(b.shelves.single.topics.single.titleFor('so'), 'Manners of Eating and Drinking');
  });

  // The committed bundle is rebuilt by CI before the tests run, so this
  // checks the real 604-page book whenever the bundle carries the layout.
  test('the real bundle makes a 604-page book with every word placed', () {
    final file = File('assets/content/bundle.json');
    final b = ContentBundle.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
    if (b.mushaf == null) {
      markTestSkipped('bundle has no mushaf layout yet');
      return;
    }
    final book = MushafBook.from(b)!;
    expect(book.pageCount, 604);
    expect(book.page(1).lines.first.parts.single, isA<SurahHeader>());
    expect(book.firstPageOf(2), 2);
    expect(book.pageOf('2:255'), 42);
    expect(book.page(604).ayat.last.key, '114:6');
    // Every word of every ayah appears exactly once across the pages.
    var words = 0;
    for (final p in book.pages) {
      for (final part in p.ayahParts) {
        words += part.to - part.from;
      }
    }
    expect(words, b.surahs.expand((s) => s.ayat).fold<int>(0, (t, a) => t + a.words.length));
    // Pages after the opening two use 15 lines.
    expect(book.page(3).lines.length, 15);
  });
}
