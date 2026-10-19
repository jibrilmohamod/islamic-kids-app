// Run: flutter test
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/local_store.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('store_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  File main() => File('${dir.path}/${LocalStore.fileName}');
  File backup() => File('${dir.path}/${LocalStore.fileName}.bak');

  test('a fresh install starts empty and writes nothing until something changes', () async {
    final store = await LocalStore.open(dir);
    expect(store.state.lastPage, 1);
    expect(store.migrated, isFalse);
    await store.flush();
    expect(main().existsSync(), isFalse);
  });

  test('changes survive a reopen', () async {
    final a = await LocalStore.open(dir);
    a.update((s) {
      s.lang = 'en';
      s.lastPage = 42;
      s.rounds = ['1:0', '114:0'];
      s.minutesByDay = {'2026-10-19': 12};
    });
    a.toggleBookmark('2:255');
    a.toggleFavourite('dua:abc');
    a.record(const HistoryEntry(kind: HistoryKind.listen, surah: 36, ayah: 4, atMs: 1000));
    await a.flush();

    final b = await LocalStore.open(dir);
    expect(b.state.lastPage, 42);
    expect(b.state.rounds, ['1:0', '114:0']);
    expect(b.state.minutesByDay, {'2026-10-19': 12});
    expect(b.isBookmarked('2:255'), isTrue);
    expect(b.isFavourite('dua:abc'), isTrue);
    expect(b.last(HistoryKind.listen)?.surah, 36);
    expect(b.last(HistoryKind.read), isNull);
  });

  test('writes are batched and land after the debounce', () async {
    final store = await LocalStore.open(dir);
    store.update((s) => s.lastPage = 5);
    store.update((s) => s.lastPage = 6);
    expect(main().existsSync(), isFalse);
    await Future<void>.delayed(LocalStore.debounce + const Duration(milliseconds: 200));
    final j = jsonDecode(main().readAsStringSync()) as Map<String, dynamic>;
    expect(j['formatVersion'], LocalStore.formatVersion);
    expect((j['data'] as Map)['lastPage'], 6);
  });

  test('a damaged file falls back to the previous good one', () async {
    final store = await LocalStore.open(dir);
    store.update((s) => s.lastPage = 10);
    await store.flush();
    store.update((s) => s.lastPage = 11);
    await store.flush();
    expect(backup().existsSync(), isTrue);
    main().writeAsStringSync('{"formatVersion": 1, "data": {"lastP'); // cut off mid-write
    final again = await LocalStore.open(dir);
    expect(again.state.lastPage, 10);
  });

  test('a file from a newer app version is not read', () async {
    main().writeAsStringSync(jsonEncode({'formatVersion': LocalStore.formatVersion + 1, 'data': {'lastPage': 99}}));
    final store = await LocalStore.open(dir);
    expect(store.state.lastPage, 1);
  });

  test('wrong or missing fields fall back to defaults, one field at a time', () async {
    main().writeAsStringSync(jsonEncode({
      'formatVersion': 1,
      'data': {
        'lastPage': 'forty',
        'dailyLimit': 30,
        'rounds': ['1:0', 7, null],
        'history': [
          {'kind': 'listen', 'surah': 1, 'ayah': 0, 'at': 5},
          {'kind': 'sing', 'surah': 1, 'ayah': 0, 'at': 5},
          {'kind': 'read', 'surah': 200, 'ayah': 0, 'at': 5},
        ],
      },
    }));
    final store = await LocalStore.open(dir);
    expect(store.state.lastPage, 1);
    expect(store.state.dailyLimit, 30);
    expect(store.state.rounds, ['1:0']);
    expect(store.state.history, [const HistoryEntry(kind: HistoryKind.listen, surah: 1, ayah: 0, atMs: 5)]);
  });

  test('values from the old SharedPreferences are carried over once', () async {
    var asked = 0;
    Future<LegacyPrefs?> legacy() async {
      asked++;
      return const LegacyPrefs(
        lang: 'en',
        rounds: ['1:0'],
        legacyCompleted: ['order-surah-112'],
        activeDays: ['2026-10-18'],
        minutes: ['2026-10-18:20', 'broken'],
        extra: ['2026-10-18:10'],
        dailyLimit: 45,
        lastPage: 604,
        homeIntroDay: '2026-10-18',
      );
    }

    final first = await LocalStore.open(dir, legacy: legacy);
    expect(first.migrated, isTrue);
    final s = first.state;
    expect(s.lang, 'en');
    expect(s.rounds, ['1:0']);
    expect(s.legacyCompleted, ['order-surah-112']);
    expect(s.activeDays, {'2026-10-18'});
    expect(s.minutesByDay, {'2026-10-18': 20});
    expect(s.extraByDay, {'2026-10-18': 10});
    expect(s.dailyLimit, 45);
    expect(s.lastPage, 604);
    expect(main().existsSync(), isTrue, reason: 'migration is written at once');

    final second = await LocalStore.open(dir, legacy: legacy);
    expect(second.migrated, isFalse);
    expect(asked, 1);
    expect(second.state.dailyLimit, 45);
  });

  test('history keeps one line per surah and kind, newest first, capped', () async {
    final store = await LocalStore.open(dir);
    store.record(const HistoryEntry(kind: HistoryKind.read, surah: 2, ayah: 0, atMs: 1));
    store.record(const HistoryEntry(kind: HistoryKind.listen, surah: 2, ayah: 3, atMs: 2));
    store.record(const HistoryEntry(kind: HistoryKind.read, surah: 2, ayah: 9, atMs: 3));
    expect(store.state.history.map((e) => (e.kind, e.ayah)), [(HistoryKind.read, 9), (HistoryKind.listen, 3)]);
    for (var n = 1; n <= 114; n++) {
      store.record(HistoryEntry(kind: HistoryKind.read, surah: n, ayah: 0, atMs: 10 + n));
    }
    expect(store.state.history.length, LocalStore.historyCap);
    expect(store.last(HistoryKind.read)?.surah, 114);
  });

  test('bookmarks toggle and keep the newest first', () async {
    final store = await LocalStore.open(dir);
    expect(store.toggleBookmark('1:1'), isTrue);
    expect(store.toggleBookmark('2:255'), isTrue);
    expect(store.state.bookmarks, ['2:255', '1:1']);
    expect(store.toggleBookmark('1:1'), isFalse);
    expect(store.state.bookmarks, ['2:255']);
  });
}
