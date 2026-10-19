// Run: flutter test
// Dummy strings only; real text comes from the pipeline.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/models.dart';
import 'package:islamic_kids_app/screens/home_screen.dart';
import 'package:islamic_kids_app/screens/order_game_screen.dart';

Map<String, dynamic> _ayah(int n, String arabic) => {
      'key': '109:$n',
      'aya': n,
      'arabic': arabic,
      'meaning': {
        'en': {'text': 'EN $n', 'footnotes': '', 'source': 'english_saheeh'},
        'so': {'text': 'SO $n', 'footnotes': '', 'source': 'somali_yacob'},
      },
    };

final _bundleJson = <String, dynamic>{
  'bundleVersion': '20261019',
  'languages': ['en', 'so'],
  'sources': {
    'somali_yacob': {'publisher': 'QuranEnc.com', 'title': 'Somali', 'version': '1.0.26', 'url': 'https://quranenc.com'},
  },
  'surahs': [
    {
      'id': 'surah-109',
      'number': 109,
      'name': 'Al-Kafirun',
      'nameAr': 'الكافرون',
      'ayat': [_ayah(1, 'A'), _ayah(2, 'B'), _ayah(3, 'C'), _ayah(4, 'D'), _ayah(5, 'C'), _ayah(6, 'E')],
    },
  ],
  'hadith': [
    {
      'id': 'hadith-1',
      'hadeethencId': '1',
      'group': 'manners-eating',
      'ar': {'text': 'AR'},
      'en': {'title': 'T', 'text': 'X', 'explanation': 'E', 'attribution': 'A', 'grade': 'G'},
      'so': {'title': 'Ts', 'text': 'Xs', 'explanation': 'Es', 'attribution': 'As', 'grade': 'Gs'},
    },
  ],
  'duas': [
    {'id': 'dua-quran-20-114', 'kind': 'quran', 'moment': 'anytime', 'key': '20:114', 'arabic': 'Q', 'meaning': <String, dynamic>{}},
    {
      'id': 'dua-hadith-2',
      'kind': 'hadith',
      'moment': 'morning-evening',
      'hadeethencId': '2',
      'ar': {'text': 'H'},
      'en': {'title': 'T2', 'text': 'X2', 'explanation': '', 'attribution': 'A', 'grade': 'G'},
      'so': {'title': 'T2s', 'text': 'X2s', 'explanation': '', 'attribution': 'A', 'grade': 'G'},
    },
  ],
};

void main() {
  final bundle = ContentBundle.fromJson(_bundleJson);

  test('bundle parses', () {
    expect(bundle.surahs.single.ayat.length, 6);
    expect(bundle.surahs.single.ayat.first.meaning['so']!.text, 'SO 1');
    expect(bundle.hadith.single.t('so').title, 'Ts');
    expect(bundle.duas.first.isQuran, isTrue);
    expect(bundle.duas.last.hadith!.arabic, 'H');
    expect(bundle.source('somali_yacob')!.label, 'QuranEnc.com · Somali · v1.0.26');
  });

  test('order game accepts identical repeated ayat in either order', () {
    final ayat = bundle.surahs.single.ayat;
    final game = OrderGame(ayat, random: Random(1));
    expect(game.shuffled.map((a) => a.key), isNot(equals(ayat.map((a) => a.key))));
    expect(game.tap(ayat[1]), isFalse); // B before A is wrong
    expect(game.tap(ayat[0]), isTrue);
    expect(game.tap(ayat[1]), isTrue);
    expect(game.tap(ayat[4]), isTrue); // ayah 5 has the same text as ayah 3
    expect(game.tap(ayat[3]), isTrue);
    expect(game.tap(ayat[2]), isTrue);
    expect(game.tap(ayat[5]), isTrue);
    expect(game.done, isTrue);
    expect(game.placed['109:5'], 3);
  });

  test('missing optional language falls back to English', () {
    final b = ContentBundle.fromJson({
      'languages': ['en'],
      'optionalLanguages': ['so'],
      'hadith': [
        {
          'id': 'hadith-9',
          'ar': {'text': 'AR'},
          'en': {'title': 'English title', 'text': 'X', 'explanation': '', 'attribution': 'A', 'grade': 'G'},
        },
      ],
      'surahs': [
        {
          'id': 'surah-1',
          'number': 1,
          'ayat': [
            {
              'key': '1:1',
              'aya': 1,
              'arabic': 'A',
              'meaning': {
                'en': {'text': 'EN', 'footnotes': '', 'source': 'english_saheeh'},
              },
            },
          ],
        },
      ],
    });
    expect(b.optionalLanguages, ['so']);
    expect(b.hadith.single.has('so'), isFalse);
    expect(b.hadith.single.t('so').title, 'English title');
    expect(b.surahs.single.ayat.single.meaningFor('so')!.text, 'EN');
  });

  test('dua for now follows the time of day', () {
    expect(duaForNow(bundle.duas, DateTime(2026, 10, 19, 7))!.moment, 'morning-evening');
    expect(duaForNow(bundle.duas, DateTime(2026, 10, 19, 13))!.moment, 'anytime');
    expect(duaForNow(const [], DateTime(2026)), isNull);
  });
}
