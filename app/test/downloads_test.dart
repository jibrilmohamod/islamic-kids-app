// Run: flutter test
//
// Saved audio: grouping files by surah, sizes, and the downloads page
// (finish a half-saved surah, remove one) over real files in a temp folder
// (test audit T4, issue #6).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/audio_service.dart';
import 'package:islamic_kids_app/local_store.dart';
import 'package:islamic_kids_app/models.dart';
import 'package:islamic_kids_app/screens/downloads_screen.dart';

import 'harness.dart';

void main() {
  final bundle = fixtureBundle();
  Surah surah(int n) => bundle.surahs.firstWhere((s) => s.number == n);

  test('saved files are grouped by surah; empty surahs are left out', () {
    final ikhlas = surah(112), falaq = surah(113);
    final files = {
      for (final a in ikhlas.ayat) a.n!: 1000,
      falaq.ayat.first.n!: 500,
    };
    final saved = savedSurahs(bundle.surahs, files);
    expect(saved.map((x) => x.surah.number), [112, 113]);
    expect((saved[0].saved, saved[0].bytes, saved[0].complete), (ikhlas.ayat.length, 1000 * ikhlas.ayat.length, true));
    expect((saved[1].saved, saved[1].complete), (1, false));
  });

  test('sizes show one decimal under 10 MB, whole numbers above', () {
    const mb = 1024 * 1024;
    expect(megabytes(0), '0.0');
    expect(megabytes(mb * 3 ~/ 2), '1.5');
    expect(megabytes(mb * 12), '12');
  });

  late Directory dir;
  late LocalStore store;
  setUp(() => dir = Directory.systemTemp.createTempSync('downloads_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// Runs [action] on the real clock, so the page's file work (started by
  /// it) can finish, then draws the result. The fake test clock would leave
  /// that work waiting forever, and the loading spinner never settles.
  Future<void> real(WidgetTester tester, Future<void> Function() action) async {
    await tester.runAsync(() async {
      await action();
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await tester.pump();
      }
    });
    await tester.pump();
  }

  testWidgets('nothing saved says so', (tester) async {
    usePhone(tester);
    final (state, s) = await testState(tester, dir);
    store = s;
    state.audio = AudioService(info: state.bundle!.audio!, baseDir: () async => dir);
    await real(tester, () => tester.pumpWidget(testApp(state, const DownloadsScreen())));
    expect(find.byIcon(Icons.download_for_offline_outlined), findsOneWidget);
    await tester.runAsync(store.flush);
  });

  testWidgets('finish a half-saved surah, then remove a saved one', (tester) async {
    usePhone(tester);
    final (state, s) = await testState(tester, dir);
    store = s;
    final fetched = <Uri>[];
    final audio = AudioService(
      info: state.bundle!.audio!,
      baseDir: () async => dir,
      download: (url, file) async {
        fetched.add(url);
        await file.writeAsBytes(List.filled(100, 1));
      },
    );
    state.audio = audio;
    final ikhlas = state.bundle!.surahs.firstWhere((x) => x.number == 112);
    final falaq = state.bundle!.surahs.firstWhere((x) => x.number == 113);
    await tester.runAsync(() async {
      for (final a in ikhlas.ayat) {
        await (await audio.fileFor(a)).writeAsBytes(List.filled(100, 1));
      }
      await (await audio.fileFor(falaq.ayat.first)).writeAsBytes(List.filled(100, 1));
    });

    await real(tester, () => tester.pumpWidget(testApp(state, const DownloadsScreen())));
    expect(find.text(ikhlas.name), findsOneWidget);
    expect(find.text('1 of ${falaq.ayat.length} ayat saved'), findsOneWidget);
    expect(find.text('2 surahs, 0.0 MB on this phone'), findsOneWidget);

    // Save the rest downloads only the missing ayat.
    await real(tester, () => tester.tap(find.byTooltip('Save the rest')));
    expect(fetched, hasLength(falaq.ayat.length - 1));
    expect(find.text('1 of ${falaq.ayat.length} ayat saved'), findsNothing);
    expect(find.byTooltip('Save the rest'), findsNothing);
    expect(find.byTooltip('Listen to the surah'), findsNWidgets(2));

    // Removing asks first; cancel keeps the files.
    final removeIkhlas = find.descendant(
      of: find.ancestor(of: find.text(ikhlas.name), matching: find.byType(Row)).first,
      matching: find.byTooltip('Remove saved audio'),
    );
    // Opened on the real clock: the delete that follows the dialog is file work.
    await real(tester, () => tester.tap(removeIkhlas));
    expect(find.text('Remove the saved audio for ${ikhlas.name}?'), findsOneWidget);
    await real(tester, () => tester.tap(find.text('Cancel')));
    expect(find.text(ikhlas.name), findsOneWidget);

    // Opened on the real clock: the delete that follows the dialog is file work.
    await real(tester, () => tester.tap(removeIkhlas));
    await real(tester, () => tester.tap(find.widgetWithText(TextButton, 'Remove saved audio')));
    expect(find.text(ikhlas.name), findsNothing);
    final left = (await tester.runAsync(audio.savedFiles))!;
    expect(ikhlas.ayat.any((a) => left.containsKey(a.n)), isFalse);
    expect(falaq.ayat.every((a) => left.containsKey(a.n)), isTrue);
    await tester.runAsync(store.flush);
  });

  testWidgets('downloads fit their text at 2x', (tester) async {
    usePhone(tester);
    final (state, s) = await testState(tester, dir);
    store = s;
    final audio = AudioService(info: state.bundle!.audio!, baseDir: () async => dir);
    state.audio = audio;
    await tester.runAsync(() async {
      for (final n in [2, 18, 36]) {
        final x = state.bundle!.surahs.firstWhere((s) => s.number == n);
        await (await audio.fileFor(x.ayat.first)).writeAsBytes([1]);
      }
    });
    await real(tester, () => tester.pumpWidget(testApp(state, const DownloadsScreen(), textScale: 2)));
    expect(tester.takeException(), isNull);
    await tester.runAsync(store.flush);
  });
}
