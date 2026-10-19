// Run: flutter test
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/app_state.dart';
import 'package:islamic_kids_app/audio_service.dart';
import 'package:islamic_kids_app/models.dart';
import 'package:islamic_kids_app/recitation.dart';
import 'package:islamic_kids_app/screens/now_playing.dart';
import 'package:islamic_kids_app/theme.dart';

Surah surah(int number, int ayat) => Surah(
      id: 'surah-$number',
      number: number,
      name: 'S$number',
      nameAr: '',
      ayat: [
        for (var i = 1; i <= ayat; i++) Ayah(key: '$number:$i', aya: i, n: i, arabic: 'A$i', meaning: const {}),
      ],
    );

/// A player that records what it was told and lets the test finish files.
class FakePlayer implements RecitationPlayer {
  final playlist = <String>[];
  int? current;
  bool isPlaying = false;
  final _index = StreamController<int?>.broadcast(sync: true);
  final _end = StreamController<void>.broadcast(sync: true);
  final _playing = StreamController<bool>.broadcast(sync: true);

  /// The file playing now ends: move on, or end the playlist.
  void finishFile() {
    final i = current!;
    if (i + 1 < playlist.length) {
      current = i + 1;
      _index.add(current);
    } else {
      isPlaying = false;
      _playing.add(false);
      _end.add(null);
    }
  }

  @override
  Stream<int?> get indexStream => _index.stream;
  @override
  Stream<void> get endStream => _end.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Future<void> load(String path) async {
    playlist
      ..clear()
      ..add(path);
    current = 0;
    _index.add(0);
  }

  @override
  Future<void> add(String path) async => playlist.add(path);

  @override
  Future<void> seekToIndex(int index) async {
    current = index;
    _index.add(index);
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late Directory dir;
  late List<int> fetched;
  late Set<int> failing;
  late Map<int, Completer<void>> gates;
  late FakePlayer player;
  late Recitation rec;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('recitation_test');
    fetched = [];
    failing = {};
    gates = {};
    player = FakePlayer();
    final files = AudioService(
      info: const AudioInfo(
          urlTemplate: 'https://cdn.example/{n}.mp3', edition: 'e', bitrate: 64, reciter: 'R', publisher: 'P', terms: 'T'),
      baseDir: () async => dir,
      download: (url, file) async {
        final n = int.parse(url.pathSegments.last.replaceAll('.mp3', ''));
        await gates[n]?.future;
        if (failing.contains(n)) throw const SocketException('offline');
        fetched.add(n);
        await file.writeAsBytes([n]);
      },
    );
    rec = Recitation(files: files, player: player);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> settle() => pumpEventQueue();

  test('recites to the end of the surah, a few ayat ahead, without pauses', () async {
    final s = surah(1, 7);
    await rec.start(s, 0);
    await settle();
    expect(rec.playing, isTrue);
    // Ayah 1 plays; 2, 3 and 4 are already queued in the same playlist.
    expect(player.playlist.length, 1 + Recitation.ahead);
    expect(fetched, [1, 2, 3, 4]);

    for (var i = 1; i < 7; i++) {
      player.finishFile();
      await settle();
      expect(rec.index, i);
      expect(rec.key, '1:${i + 1}');
    }
    expect(player.playlist.length, 7);
    player.finishFile();
    await settle();
    expect(rec.active, isFalse);
  });

  test('one ayah only when not asked to carry on', () async {
    final s = surah(2, 5);
    await rec.start(s, 2, toEnd: false);
    await settle();
    expect(rec.toEnd, isFalse);
    expect(player.playlist.length, 1);
    player.finishFile();
    await settle();
    expect(rec.active, isFalse);
  });

  test('waits for a slow download, then carries on by itself', () async {
    final s = surah(3, 3);
    gates[2] = Completer<void>();
    await rec.start(s, 0);
    await settle();
    expect(player.playlist.length, 1);
    player.finishFile(); // ayah 1 ends before ayah 2 has arrived
    await settle();
    expect(rec.waiting, isTrue);
    expect(rec.active, isTrue);
    gates[2]!.complete();
    await settle();
    expect(rec.waiting, isFalse);
    expect(rec.index, 1);
    expect(player.isPlaying, isTrue);
  });

  test('a failed download mid-surah stops after what is queued and is reported', () async {
    final s = surah(4, 6);
    failing.add(3);
    await rec.start(s, 0);
    await settle();
    expect(rec.failures.value, 1);
    expect(player.playlist.length, 2);
    player.finishFile();
    await settle();
    player.finishFile();
    await settle();
    expect(rec.active, isFalse);
  });

  test('the first ayah failing throws and leaves nothing playing', () async {
    failing.add(1);
    await expectLater(rec.start(surah(5, 3), 0), throwsA(isA<SocketException>()));
    expect(rec.active, isFalse);
  });

  test('stop ends it, and a new surah replaces the old one', () async {
    await rec.start(surah(6, 4), 0);
    await settle();
    await rec.start(surah(7, 4), 1);
    await settle();
    expect(rec.surah!.number, 7);
    expect(rec.index, 1);
    await rec.stop();
    expect(rec.active, isFalse);
    expect(player.isPlaying, isFalse);
  });

  test('next and previous move by one ayah', () async {
    await rec.start(surah(8, 5), 1);
    await settle();
    await rec.next();
    await settle();
    expect(rec.index, 2);
    await rec.previous();
    await settle();
    expect(rec.index, 1);
    expect(rec.toEnd, isTrue);
  });

  test('the same ayah is downloaded once when two callers want it', () async {
    final files = rec.files;
    gates[1] = Completer<void>();
    final a = surah(9, 1).ayat.first;
    final both = Future.wait([files.ensure(a), files.ensure(a)]);
    gates[1]!.complete();
    await both;
    expect(fetched, [1]);
  });

  testWidgets('the now-playing strip shows the ayah and stops it', (tester) async {
    final state = AppState()..recitation = rec;
    Widget strip() => AppScope(
          state: state,
          child: MaterialApp(theme: popTheme(), home: const Scaffold(bottomNavigationBar: NowPlayingBar())),
        );
    await tester.pumpWidget(strip());
    expect(find.text('S10'), findsNothing);
    await tester.runAsync(() async {
      await rec.start(surah(10, 4), 1);
      await pumpEventQueue();
    });
    await tester.pump();
    expect(find.text('S10'), findsOneWidget);
    expect(find.text('Ayah 2 of 4'), findsOneWidget);
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    expect(rec.active, isFalse);
    expect(find.text('S10'), findsNothing);
  });
}
