// Run: flutter test
//
// The mosaic of surahs and the put-in-order game, played through the
// screens (test audit T4, issue #6). Game rules themselves are in
// logic_test.dart.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/local_store.dart';
import 'package:islamic_kids_app/progress.dart';
import 'package:islamic_kids_app/screens/mosaic_screen.dart';
import 'package:islamic_kids_app/screens/order_game_screen.dart';
import 'package:islamic_kids_app/screens/surah_screen.dart';

import 'harness.dart';

void main() {
  late Directory dir;
  late LocalStore store;
  setUp(() => dir = Directory.systemTemp.createTempSync('games_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('the mosaic counts glazed tiles and opens a surah', (tester) async {
    usePhone(tester);
    final (state, s) = await testState(tester, dir);
    store = s;
    final ikhlas = state.bundle!.surahs.firstWhere((x) => x.number == 112);
    state.completeRound(ikhlas, 0);
    await tester.pumpWidget(testApp(state, const MosaicScreen()));
    await tester.pumpAndSettle();
    expect(find.text('1 of 114 glazed'), findsOneWidget);
    final fatiha = state.bundle!.surahs.first;
    await tester.tap(find.text(fatiha.name));
    await tester.pumpAndSettle();
    expect(find.byType(SurahScreen), findsOneWidget);
    await tester.runAsync(store.flush);
  });

  testWidgets('order game: a wrong tile says try again; the right order glazes the surah', (tester) async {
    usePhone(tester);
    final (state, s) = await testState(tester, dir);
    store = s;
    final ikhlas = state.bundle!.surahs.firstWhere((x) => x.number == 112);
    expect(roundsFor(ikhlas.ayat.length), hasLength(1));
    await tester.pumpWidget(testApp(state, OrderGameScreen(surah: ikhlas, round: 0)));
    await tester.pumpAndSettle();
    expect(find.text('0 of ${ikhlas.ayat.length}'), findsOneWidget);

    // The last ayah is never right first.
    await tester.tap(find.text(ikhlas.ayat.last.arabic));
    await tester.pump();
    expect(find.text('Not that one. Try again'), findsOneWidget);
    expect(find.text('0 of ${ikhlas.ayat.length}'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));

    for (final (i, a) in ikhlas.ayat.indexed) {
      final tile = find.text(a.arabic);
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pump();
      expect(find.text('${i + 1} of ${ikhlas.ayat.length}'), findsOneWidget);
    }
    await tester.pump(const Duration(seconds: 1)); // the "nice" burst's timer
    await tester.pumpAndSettle();
    expect(state.progress.isGlazed(ikhlas), isTrue);
    expect(store.state.rounds, contains('112:0'));
    expect(find.text('Tile glazed!'), findsOneWidget);
    expect(find.text('Back to the surah'), findsOneWidget);
    expect(find.text('Next round'), findsNothing, reason: 'one round only');
    await tester.runAsync(store.flush);
  });

  testWidgets('a long surah is played in rounds; done rounds are marked', (tester) async {
    usePhone(tester);
    final (state, s) = await testState(tester, dir);
    store = s;
    final mulk = state.bundle!.surahs.firstWhere((x) => x.number == 67);
    final rounds = roundsFor(mulk.ayat.length);
    expect(rounds.length, greaterThan(1));
    state.completeRound(mulk, 0);
    await tester.pumpWidget(testApp(state, RoundPickerScreen(surah: mulk)));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of ${rounds.length}'), findsWidgets);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    final second = rounds[1];
    await tester.tap(find.text('Round 2: ayat ${second.start + 1} to ${second.end}'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderGameScreen), findsOneWidget);
    expect(find.text('0 of ${second.end - second.start}'), findsOneWidget);
    await tester.runAsync(store.flush);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('game pages fit their text at ${scale}x', (tester) async {
      usePhone(tester);
      final (state, s) = await testState(tester, dir);
      store = s;
      final surahs = state.bundle!.surahs;
      for (final page in <Widget>[
        const MosaicScreen(),
        RoundPickerScreen(surah: surahs.firstWhere((x) => x.number == 2)),
        OrderGameScreen(surah: surahs.firstWhere((x) => x.number == 112), round: 0),
        OrderGameScreen(surah: surahs.firstWhere((x) => x.number == 2), round: 0),
      ]) {
        await tester.pumpWidget(testApp(state, KeyedSubtree(key: UniqueKey(), child: page), textScale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$page at ${scale}x');
      }
      await tester.runAsync(store.flush);
    });
  }
}
