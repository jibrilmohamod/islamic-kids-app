// Renders key screens to PNG with the real fonts and the real bundle.
// Run by CI with:  flutter test --update-goldens test_screens/
// Not part of the normal test run (the images are previews, not checks).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/app_state.dart';
import 'package:islamic_kids_app/local_store.dart';
import 'package:islamic_kids_app/models.dart';
import 'package:islamic_kids_app/screens/hadith_screen.dart';
import 'package:islamic_kids_app/screens/home_screen.dart';
import 'package:islamic_kids_app/screens/mushaf_screen.dart';
import 'package:islamic_kids_app/screens/my_shelf_screen.dart';
import 'package:islamic_kids_app/screens/surah_screen.dart';
import 'package:islamic_kids_app/theme.dart';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final file = File(f);
    if (!file.existsSync()) return;
    loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  await _font('Bungee', ['assets/fonts/Bungee-Regular.ttf']);
  await _font('Baloo 2', ['assets/fonts/Baloo2-Medium.ttf', 'assets/fonts/Baloo2-Bold.ttf', 'assets/fonts/Baloo2-ExtraBold.ttf']);
  await _font('Scheherazade New', ['assets/fonts/ScheherazadeNew-Regular.ttf']);
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    await _font('MaterialIcons', ['$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  }
}

late AppState _state;

Widget _app(Widget home) => AppScope(
      state: _state,
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: popTheme(), home: home),
    );

Future<void> _shot(WidgetTester tester, String name, Widget home) async {
  await tester.pumpWidget(_app(home));
  await tester.pump(const Duration(milliseconds: 100));
  // Past Home's opening (1.6 s) so the screen is shown as it settles.
  await tester.pump(const Duration(milliseconds: 2000));
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    final raw = File('assets/content/bundle.json').readAsStringSync();
    _state = AppState()..bundle = ContentBundle.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  // A mid-range Android phone: 412 x 892 dp at 2x.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(824, 1784);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  testWidgets('home', (tester) async {
    phone(tester);
    await _shot(tester, 'home', const HomeScreen());
  });

  for (final p in [1, 2, 3, 42, 293, 604]) {
    testWidgets('mushaf page $p', (tester) async {
      phone(tester);
      if (_state.book == null) return;
      await _shot(tester, 'mushaf_$p', MushafScreen(initialPage: p));
    });
  }

  testWidgets('mushaf with an ayah selected', (tester) async {
    phone(tester);
    if (_state.book == null) return;
    await _shot(tester, 'mushaf_42_selected', const MushafScreen(initialPage: 42, selectKey: '2:255'));
  });

  testWidgets('hadith shelves', (tester) async {
    phone(tester);
    await _shot(tester, 'hadith_shelves', const HadithListScreen());
  });

  testWidgets('hadith topic and detail', (tester) async {
    phone(tester);
    final b = _state.bundle!;
    final topic = b.shelves.isNotEmpty ? b.shelves.first.topics.first.id : b.hadith.first.group;
    await _shot(tester, 'hadith_topic', TopicScreen(topicId: topic));
    final withRefs = b.hadith.where((h) => h.refs.length == 2).firstOrNull ?? b.hadith.first;
    await _shot(tester, 'hadith_detail', HadithScreen(hadith: withRefs));
  });

  testWidgets('hadith shelf', (tester) async {
    phone(tester);
    final b = _state.bundle!;
    if (b.shelves.isEmpty) return;
    await _shot(tester, 'hadith_shelf', ShelfScreen(shelf: b.shelves.first));
  });

  testWidgets('surah', (tester) async {
    phone(tester);
    await _shot(tester, 'surah_36', SurahScreen(surah: _state.bundle!.surahs.firstWhere((s) => s.number == 36)));
  });

  testWidgets('my shelf', (tester) async {
    phone(tester);
    final dir = Directory.systemTemp.createTempSync('shelf_preview');
    final store = (await tester.runAsync(() => LocalStore.open(dir, autoFlush: null)))!;
    // test_screens/ is a test folder the analyzer does not recognise as one.
    // ignore: invalid_use_of_visible_for_testing_member
    _state.store = store;
    final b = _state.bundle!;
    _state
      ..toggleBookmark('36:1')
      ..toggleBookmark('2:255')
      ..toggleBookmark('112:1')
      ..toggleFavourite('hadith:${b.hadith.first.id}')
      ..toggleFavourite('dua:${b.duas.last.id}')
      ..recordHistory(HistoryKind.read, 36, 0)
      ..recordHistory(HistoryKind.listen, 67, 11);
    await _shot(tester, 'my_shelf', const MyShelfScreen());
    await tester.runAsync(store.flush);
  });
}
