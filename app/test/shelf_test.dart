// Run: flutter test
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/app_state.dart';
import 'package:islamic_kids_app/arch.dart';
import 'package:islamic_kids_app/local_store.dart';
import 'package:islamic_kids_app/models.dart';
import 'package:islamic_kids_app/screens/hadith_screen.dart';
import 'package:islamic_kids_app/screens/my_shelf_screen.dart';
import 'package:islamic_kids_app/theme.dart';
import 'package:islamic_kids_app/widgets.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('shelf_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  late LocalStore store;

  /// Writes pending changes now, so no debounce timer outlives the test.
  Future<void> flush(WidgetTester tester) => tester.runAsync(store.flush);

  Future<AppState> stateWithStore(WidgetTester tester) async {
    final raw = File('test/fixtures/bundle.json').readAsStringSync();
    final state = AppState()
      ..bundle = ContentBundle.fromJson(jsonDecode(raw) as Map<String, dynamic>)
      ..now = () => DateTime(2026, 10, 20, 9);
    store = (await tester.runAsync(() => LocalStore.open(dir, autoFlush: null)))!;
    state.store = store;
    return state;
  }

  Widget app(AppState state, Widget home, {double textScale = 1}) => AppScope(
        state: state,
        child: MaterialApp(
          theme: popTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(412, 892),
              disableAnimations: true,
              textScaler: TextScaler.linear(textScale),
            ),
            child: home,
          ),
        ),
      );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(824, 1784);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  testWidgets('an empty shelf says how to fill it', (tester) async {
    phone(tester);
    final state = await stateWithStore(tester);
    await tester.pumpWidget(app(state, const MyShelfScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing here yet'), findsOneWidget);
  });

  testWidgets('bookmarks, favourites and history show on the shelf', (tester) async {
    phone(tester);
    final state = await stateWithStore(tester);
    final h = state.bundle!.hadith.first;
    state
      ..toggleBookmark('36:1')
      ..toggleFavourite(favouriteId(h))
      ..recordHistory(HistoryKind.listen, 36, 4);
    await tester.pumpWidget(app(state, const MyShelfScreen()));
    await tester.pumpAndSettle();
    final yaseen = state.bundle!.surahs.firstWhere((s) => s.number == 36).name;
    expect(find.text('$yaseen 36:1'), findsOneWidget);
    expect(find.text(h.t('en').title), findsOneWidget);
    expect(find.text('Carry on'), findsOneWidget);
    expect(find.text('Ayah 5 of 83'), findsOneWidget);
    expect(find.textContaining('Nothing here yet'), findsNothing);
    await flush(tester);
  });

  testWidgets('the heart on a hadith topic keeps it as a favourite', (tester) async {
    phone(tester);
    final state = await stateWithStore(tester);
    final group = state.bundle!.hadith.first.group;
    final inGroup = state.bundle!.hadith.where((x) => x.group == group);
    // The topic lists short hadith first; take the one at the top.
    final h = inGroup.firstWhere((x) => x.isShort, orElse: () => inGroup.first);
    await tester.pumpWidget(app(state, TopicScreen(topicId: group)));
    await tester.pumpAndSettle();
    expect(state.isFavourite(favouriteId(h)), isFalse);
    final card = find.ancestor(of: find.text(h.t('en').title), matching: find.byType(GlazeCard)).first;
    final heart = find.descendant(of: card, matching: find.byType(ToggleIconButton));
    await tester.ensureVisible(heart);
    await tester.pumpAndSettle();
    await tester.tap(heart);
    await tester.pumpAndSettle();
    expect(state.isFavourite(favouriteId(h)), isTrue);
    expect(find.byTooltip('Remove from my favourites'), findsOneWidget);
    await flush(tester);
  });

  testWidgets('hadith shelves are niches that open their topics', (tester) async {
    phone(tester);
    final state = await stateWithStore(tester);
    await tester.pumpWidget(app(state, const HadithListScreen()));
    await tester.pumpAndSettle();
    final niches = find.byType(ArchNiche);
    expect(niches, findsWidgets);
    await tester.tap(niches.first);
    await tester.pumpAndSettle();
    expect(find.byType(ShelfScreen), findsOneWidget);
  });

  // Text must fit by wrapping, never by overflowing, at the largest text
  // size Android offers (200%). An overflow fails the test.
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('pages fit their text at ${scale}x', (tester) async {
      phone(tester);
      final state = await stateWithStore(tester);
      final h = state.bundle!.hadith.first;
      state
        ..toggleBookmark('36:1')
        ..toggleBookmark('2:255')
        ..toggleFavourite(favouriteId(h))
        ..recordHistory(HistoryKind.listen, 36, 4)
        ..recordHistory(HistoryKind.read, 18, 0);
      for (final page in <Widget>[
        const MyShelfScreen(),
        const HadithListScreen(),
        TopicScreen(topicId: h.group),
        const TopicScreen(topicId: TopicScreen.shortOnes),
      ]) {
        await tester.pumpWidget(app(state, page, textScale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${page.runtimeType} at ${scale}x');
      }
      await flush(tester);
    });
  }
}
