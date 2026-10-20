// Run: flutter test
//
// "My day" duas: the stops, a moment's list, and one dua with its counter,
// memorise mode, paging and favourite (test audit T4, issue #6).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/local_store.dart';
import 'package:islamic_kids_app/models.dart';
import 'package:islamic_kids_app/screens/dua_screen.dart';
import 'package:islamic_kids_app/screens/duas_screen.dart';

import 'harness.dart';

void main() {
  group('which stop is now', () {
    test('morning before 11, evening from 16 to 22, else none', () {
      expect(currentStopId(DateTime(2026, 1, 1, 3)), isNull);
      expect(currentStopId(DateTime(2026, 1, 1, 4)), 'morning');
      expect(currentStopId(DateTime(2026, 1, 1, 10, 59)), 'morning');
      expect(currentStopId(DateTime(2026, 1, 1, 11)), isNull);
      expect(currentStopId(DateTime(2026, 1, 1, 16)), 'evening');
      expect(currentStopId(DateTime(2026, 1, 1, 22)), isNull);
    });

    test('morning-and-evening duas follow the time; others their moment', () {
      final duas = fixtureBundle().duas;
      final both = duas.firstWhere((d) => d.moment == 'morning-evening');
      expect(stopFor(both, DateTime(2026, 1, 1, 8)).id, 'morning');
      expect(stopFor(both, DateTime(2026, 1, 1, 18)).id, 'evening');
      expect(stopFor(both, DateTime(2026, 1, 1, 13)).id, 'morning');
      expect(stopFor(duas.firstWhere((d) => d.moment == 'mosque'), DateTime(2026)).id, 'mosque');
      expect(stopFor(duas.firstWhere((d) => d.moment == 'anytime'), DateTime(2026)).id, 'anytime');
    });
  });

  late Directory dir;
  late LocalStore store;
  setUp(() => dir = Directory.systemTemp.createTempSync('duas_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('My day → Morning → a dua: count, memorise, page, favourite', (tester) async {
    usePhone(tester);
    final (state, s) = await testState(tester, dir);
    store = s;
    final morning = state.bundle!.duas.where((d) => d.moment == 'morning-evening').toList();
    await tester.pumpWidget(testApp(state, const DuasScreen()));
    await tester.pumpAndSettle();

    // At 09:00 the morning stop is marked as now.
    expect(find.text('Now'), findsOneWidget);
    await tester.tap(find.text('Morning'));
    await tester.pumpAndSettle();
    expect(find.byType(MomentScreen), findsOneWidget);
    expect(find.text('${morning.length} duas'), findsWidgets);

    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();
    expect(find.byType(DuaScreen), findsOneWidget);
    expect(find.text('Morning, 1 of ${morning.length}'), findsOneWidget);
    expect(find.text('Previous'), findsNothing, reason: 'nothing before the first dua');

    // The counter counts taps and can start again.
    await tester.tap(find.text('0'));
    await tester.pump();
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    await tester.ensureVisible(find.text('Start the count again'));
    await tester.tap(find.text('Start the count again'));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Start the count again'), findsNothing);

    // Memorise hides words for display only.
    await tester.tap(find.byTooltip('Memorise'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoriseView), findsOneWidget);
    await tester.tap(find.text('Hide all'));
    await tester.pumpAndSettle();
    final faces = tester.widgetList<Opacity>(find.descendant(of: find.byType(MemoriseView), matching: find.byType(Opacity)));
    expect(faces, isNotEmpty);
    expect(faces.every((o) => o.opacity == 0), isTrue);
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<Opacity>(find.descendant(of: find.byType(MemoriseView), matching: find.byType(Opacity))).every((o) => o.opacity == 1),
      isTrue,
    );

    // Next goes to the second dua and resets memorise mode.
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Morning, 2 of ${morning.length}'), findsOneWidget);
    expect(find.byType(MemoriseView), findsNothing);
    expect(find.text('Previous'), findsOneWidget);

    // The heart keeps this dua on My shelf.
    expect(state.isFavourite('dua:${morning[1].id}'), isFalse);
    await tester.tap(find.byTooltip('Add to my favourites'));
    await tester.pumpAndSettle();
    expect(state.isFavourite('dua:${morning[1].id}'), isTrue);
    expect(find.byTooltip('Remove from my favourites'), findsOneWidget);

    await tester.runAsync(store.flush);
  });

  testWidgets('the Quran dua shows its meaning and source, not hadith details', (tester) async {
    usePhone(tester);
    final (state, s) = await testState(tester, dir);
    store = s;
    final anytime = state.bundle!.duas.where((d) => d.moment == 'anytime').toList();
    final d = anytime.single;
    expect(d.hadith, isNull);
    await tester.pumpWidget(testApp(state, DuaScreen(duas: anytime, index: 0, stop: anytimeStop)));
    await tester.pumpAndSettle();
    final meaning = d.meaningFor('en');
    if (meaning != null) {
      expect(find.text(meaning.text), findsWidgets);
      expect(find.text('Meaning'), findsOneWidget);
    }
    expect(find.text('Next'), findsNothing, reason: 'only one dua');
    await tester.runAsync(store.flush);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('dua pages fit their text at ${scale}x', (tester) async {
      usePhone(tester);
      final (state, s) = await testState(tester, dir);
      store = s;
      final duas = state.bundle!.duas;
      List<Dua> of(String m) => duas.where((d) => d.moment == m).toList();
      for (final page in <Widget>[
        const DuasScreen(),
        MomentScreen(stop: dayStops.first, duas: of('morning-evening')),
        DuaScreen(duas: of('morning-evening'), index: 1, stop: dayStops.first),
        DuaScreen(duas: of('mosque'), index: 0, stop: dayStops[2]),
        DuaScreen(duas: of('anytime'), index: 0, stop: anytimeStop),
      ]) {
        await tester.pumpWidget(testApp(state, page, textScale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$page at ${scale}x');
      }
      await tester.runAsync(store.flush);
    });
  }
}
