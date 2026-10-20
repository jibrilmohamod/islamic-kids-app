// Run: flutter test
//
// Flows across screens and the app's wiring (test audit T5, T6). Uses the
// small fixed bundle in test/fixtures, a store in a temp folder without its
// write timer, and a fake player, so nothing here touches the network.
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart' show MediaAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/activity.dart';
import 'package:islamic_kids_app/app_state.dart';
import 'package:islamic_kids_app/audio_service.dart';
import 'package:islamic_kids_app/local_store.dart';
import 'package:islamic_kids_app/main.dart';
import 'package:islamic_kids_app/models.dart';
import 'package:islamic_kids_app/progress.dart';
import 'package:islamic_kids_app/recitation.dart';
import 'package:islamic_kids_app/recitation_player.dart';
import 'package:islamic_kids_app/screens/home_screen.dart';
import 'package:islamic_kids_app/screens/mushaf_screen.dart';
import 'package:islamic_kids_app/screens/my_shelf_screen.dart';
import 'package:islamic_kids_app/screens/parent_gate.dart';
import 'package:islamic_kids_app/screens/surah_screen.dart';
import 'package:islamic_kids_app/theme.dart';

import 'recitation_test.dart' show FakePlayer;

ContentBundle fixture() =>
    ContentBundle.fromJson(jsonDecode(File('test/fixtures/bundle.json').readAsStringSync()) as Map<String, dynamic>);

void main() {
  late Directory dir;
  late LocalStore store;
  setUp(() => dir = Directory.systemTemp.createTempSync('flows_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<AppState> appState(WidgetTester tester, {SavedState? saved}) async {
    store = (await tester.runAsync(() => LocalStore.open(dir, autoFlush: null)))!;
    if (saved != null) {
      store.update((s) {
        s.legacyCompleted = saved.legacyCompleted;
        s.dailyLimit = saved.dailyLimit;
        s.minutesByDay = saved.minutesByDay;
      });
    }
    final state = AppState()
      ..bundle = fixture()
      ..now = () => DateTime(2026, 10, 20, 9);
    // ignore: invalid_use_of_visible_for_testing_member
    state.store = store;
    return state;
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(824, 1784);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Widget home(AppState state) => AppScope(
        state: state,
        child: MaterialApp(
          theme: popTheme(),
          home: const MediaQuery(
            data: MediaQueryData(size: Size(412, 892), disableAnimations: true),
            child: HomeScreen(),
          ),
        ),
      );

  // The acceptance scenario: the pieces work together, end to end.
  testWidgets('Home → keep going → bookmark an ayah → My shelf → back to it in the book', (tester) async {
    phone(tester);
    final state = await appState(tester);
    await tester.pumpWidget(home(state));
    await tester.pumpAndSettle();

    // Keep going opens the next surah in learning order: Al-Fatiha.
    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    expect(find.byType(SurahScreen), findsOneWidget);
    final fatiha = state.bundle!.surahs.firstWhere((s) => s.number == 1);

    await tester.tap(find.byTooltip('Bookmark 1:1'));
    await tester.pumpAndSettle();
    expect(state.isBookmarked('1:1'), isTrue);
    expect(find.byTooltip('Remove bookmark 1:1'), findsOneWidget);

    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();
    // My shelf is the last niche, below the fold on a phone.
    await tester.ensureVisible(find.text('My shelf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My shelf'));
    await tester.pumpAndSettle();
    expect(find.byType(MyShelfScreen), findsOneWidget);
    final chip = find.text('${fatiha.name} 1:1');
    expect(chip, findsOneWidget);

    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.byType(MushafScreen), findsOneWidget);
    await tester.runAsync(store.flush);
  });

  testWidgets('a used-up daily limit covers the app with the break screen', (tester) async {
    phone(tester);
    final now = DateTime(2026, 10, 20, 9);
    final state = await appState(tester, saved: SavedState(dailyLimit: 30, minutesByDay: {dayKey(now): 30}));
    state.activity = Activity(dailyLimit: 30, minutesByDay: {dayKey(now): 30});
    expect(state.timeUp, isTrue);
    await tester.pumpWidget(AppScope(state: state, child: const KidsApp()));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(BreakScreen), findsOneWidget);
    expect(find.textContaining('For grown-ups'), findsOneWidget);
  });

  testWidgets('v0.1 finished games become every round of that surah, once', (tester) async {
    final state = await appState(tester, saved: SavedState(legacyCompleted: ['order-surah-112', 'order-surah-999', 'junk']));
    final ikhlas = state.bundle!.surahs.firstWhere((s) => s.number == 112);
    expect(state.progress.isGlazed(ikhlas), isFalse);
    state.migrateLegacyGames(state.bundle!);
    expect(state.progress.isGlazed(ikhlas), isTrue);
    expect(store.state.legacyCompleted, isEmpty);
    expect(store.state.rounds, contains('112:0'));
    // A second run changes nothing.
    final before = List.of(store.state.rounds);
    state.migrateLegacyGames(state.bundle!);
    expect(store.state.rounds, before);
    expect(roundsFor(ikhlas.ayat.length), hasLength(1));
  });

  testWidgets('listening is recorded as history once recitation is attached', (tester) async {
    final state = await appState(tester);
    final player = FakePlayer();
    final files = AudioService(
      info: state.bundle!.audio!,
      baseDir: () async => dir,
      download: (url, file) async => file.writeAsBytes([1]),
    );
    state.attachRecitation(files, Recitation(files: files, player: player));
    final mulk = state.bundle!.surahs.firstWhere((s) => s.number == 67);
    await tester.runAsync(() async {
      await state.recitation!.start(mulk, 11);
      await pumpEventQueue();
    });
    final last = state.history.firstWhere((e) => e.kind == HistoryKind.listen);
    expect((last.surah, last.ayah), (67, 11));
    await tester.runAsync(() async {
      await state.recitation!.stop();
      await store.flush();
    });
  });

  test('the notification shows the surah, the ayah and the right buttons', () async {
    final dir = Directory.systemTemp.createTempSync('handler_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final b = fixture();
    final files = AudioService(info: b.audio!, baseDir: () async => dir, download: (url, f) async => f.writeAsBytes([1]));
    final player = FakePlayer();
    final rec = Recitation(files: files, player: player);
    // Separate statements: in a cascade, `..attach` after an arrow function
    // would bind to the function's string result.
    final handler = RecitationHandler();
    handler.ayahLabel = (n, total) => 'Ayah $n of $total';
    handler.attach(rec);
    expect(handler.mediaItem.value, isNull, reason: 'nothing playing yet');

    final yaseen = b.surahs.firstWhere((s) => s.number == 36);
    await rec.start(yaseen, 2);
    await pumpEventQueue();
    expect(handler.mediaItem.value?.title, yaseen.name);
    expect(handler.mediaItem.value?.album, 'Ayah 3 of 83');
    final playing = handler.playbackState.value;
    expect(playing.playing, isTrue);
    expect(playing.controls.map((c) => c.action).toList(), contains(MediaAction.pause));

    await handler.pause();
    await pumpEventQueue();
    expect(handler.playbackState.value.playing, isFalse);
    expect(handler.playbackState.value.controls.map((c) => c.action).toList(), contains(MediaAction.play));

    await handler.skipToNext();
    await pumpEventQueue();
    expect(rec.index, 3);

    await handler.stop();
    await pumpEventQueue();
    expect(rec.active, isFalse);
    expect(handler.mediaItem.value, isNull);
  });
}
