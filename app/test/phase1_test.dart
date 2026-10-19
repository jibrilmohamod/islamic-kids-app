// Run: flutter test
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/activity.dart';
import 'package:islamic_kids_app/models.dart';
import 'package:islamic_kids_app/screens/duas_screen.dart';
import 'package:islamic_kids_app/screens/missing_word_screen.dart';
import 'package:islamic_kids_app/widgets.dart';

Ayah ayah(int i, String arabic) => Ayah(key: '1:$i', aya: i, n: i, arabic: arabic, meaning: const {});

void main() {
  test('weeks start on Saturday', () {
    final wed = DateTime(2026, 10, 21); // a Wednesday
    final week = weekOf(wed);
    expect(week.first, DateTime(2026, 10, 17)); // Saturday
    expect(week.first.weekday, DateTime.saturday);
    expect(week.last, DateTime(2026, 10, 23));
    expect(weekOf(DateTime(2026, 10, 17, 9)).first, DateTime(2026, 10, 17));
  });

  test('weekly dots fill without any streak to lose', () {
    final a = Activity();
    final sat = DateTime(2026, 10, 17, 8);
    expect(a.markActive(sat), isTrue);
    expect(a.markActive(sat.add(const Duration(hours: 3))), isFalse);
    a.markActive(DateTime(2026, 10, 20));
    expect(a.daysThisWeek(DateTime(2026, 10, 21)), 2);
    expect(a.weekDots(DateTime(2026, 10, 21)), [true, false, false, true, false, false, false]);
    expect(a.daysThisWeek(DateTime(2026, 10, 24)), 0); // new week starts fresh
  });

  test('daily limit, extra time and stored counts', () {
    final now = DateTime(2026, 10, 19, 15);
    final a = Activity(dailyLimit: 2);
    expect(a.timeUp(now), isFalse);
    a.addMinute(now);
    a.addMinute(now);
    expect(a.timeUp(now), isTrue);
    a.allowMore(now, 15);
    expect(a.timeUp(now), isFalse);
    final restored = Activity.decodeCounts(Activity.encodeCounts(a.minutesByDay));
    expect(restored, {'2026-10-19': 2});
    expect(Activity(dailyLimit: 0).timeUp(now), isFalse);
  });

  test('parent question needs adult arithmetic', () {
    for (var seed = 0; seed < 200; seed++) {
      final q = ParentGateQuestion.random(seed);
      expect(q.a, inInclusiveRange(12, 19));
      expect(q.b, inInclusiveRange(3, 9));
      expect(q.answer, q.a * q.b);
    }
  });

  test('quoted words are highlighted without cutting any text', () {
    const text = 'قال: «بسم الله» ثم قال «الحمد لله».';
    final segs = QuotedArabic.segments(text);
    expect(segs.map((s) => s.$1).join(), text);
    expect(segs.where((s) => s.$2).map((s) => s.$1), ['«بسم الله»', '«الحمد لله»']);
    expect(QuotedArabic.segments('no quotes'), [('no quotes', false)]);
  });

  test('missing word game hides a real word and offers real words', () {
    final ayat = [
      ayah(1, 'قُلۡ هُوَ ٱللَّهُ أَحَدٌ'),
      ayah(2, 'ٱللَّهُ ٱلصَّمَدُ يَوۡمَ'),
      ayah(3, 'لَمۡ يَلِدۡ وَلَمۡ يُولَدۡ'),
    ];
    final game = MissingWordGame.build(ayat, ayat, random: Random(3));
    expect(game.questions, isNotEmpty);
    for (final q in game.questions) {
      expect(q.options.length, 3);
      expect(q.options, contains(q.answer));
      expect(bareArabic(q.answer).length, greaterThanOrEqualTo(3));
      expect(q.options.map(bareArabic).toSet().length, 3);
    }
    final first = game.question;
    final wrong = first.options.firstWhere((o) => o != first.answer);
    expect(game.answer(wrong, firstTry: true), isFalse);
    expect(game.answer(first.answer, firstTry: false), isTrue);
    expect(game.right, 0);
  });

  test('bare Arabic drops harakat and Quranic marks', () {
    expect(bareArabic('قُلۡ'), 'قل');
    expect(bareArabic('ٱللَّهُ'), 'ٱلله');
  });

  test('day stops map duas to morning or evening by the clock', () {
    const d = Dua(id: 'x', moment: 'morning-evening', arabic: 'a');
    expect(stopFor(d, DateTime(2026, 1, 1, 7)).id, 'morning');
    expect(stopFor(d, DateTime(2026, 1, 1, 18)).id, 'evening');
    expect(stopFor(const Dua(id: 'y', moment: 'mosque', arabic: 'a'), DateTime(2026)).id, 'mosque');
    expect(stopFor(const Dua(id: 'z', moment: 'anytime', arabic: 'a'), DateTime(2026)).id, 'anytime');
  });
}
