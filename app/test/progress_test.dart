// Run: flutter test
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/audio_service.dart';
import 'package:islamic_kids_app/models.dart';
import 'package:islamic_kids_app/progress.dart';
import 'package:islamic_kids_app/widgets.dart' show Glaze;

Surah surah(int number, int ayat) => Surah(
      id: 'surah-$number',
      number: number,
      name: 'S$number',
      nameAr: '',
      ayat: [
        for (var i = 1; i <= ayat; i++) Ayah(key: '$number:$i', aya: i, n: i, arabic: 'A$i', meaning: const {}),
      ],
    );

void main() {
  test('rounds split long surahs and fold a short tail into the last round', () {
    expect(roundsFor(3), [(start: 0, end: 3)]);
    expect(roundsFor(5), [(start: 0, end: 5)]);
    expect(roundsFor(6), [(start: 0, end: 6)]);
    expect(roundsFor(8), [(start: 0, end: 5), (start: 5, end: 8)]);
    expect(roundsFor(286).length, 57);
    expect(roundsFor(286).last, (start: 280, end: 286));
  });

  test('learning order starts with Al-Fatiha then An-Nas backwards', () {
    final order = learningOrder();
    expect(order.length, 114);
    expect(order.take(3), [1, 114, 113]);
    expect(order.last, 2);
  });

  test('a tile glazes only when every round is done and survives a save', () {
    final baqarahLike = surah(2, 12); // rounds of 5 and 7 (a 2-ayah tail joins the last)
    final p = Progress();
    expect(roundsFor(12).length, 2);
    expect(p.glazeOf(baqarahLike), Glaze.empty);
    p.completeRound(2, 0);
    expect(p.glazeOf(baqarahLike), Glaze.partial);
    p.completeRound(2, 1);
    expect(p.isGlazed(baqarahLike), isTrue);
    final restored = Progress(p.toSaved());
    expect(restored.glazeOf(baqarahLike), Glaze.full);
  });

  test('next up follows the learning order and marks the next tile', () {
    final fatiha = surah(1, 7);
    final nas = surah(114, 6);
    final falaq = surah(113, 5);
    final p = Progress()..completeRound(1, 0);
    final next = p.nextUp([fatiha, falaq, nas]);
    expect(next!.number, 114);
    expect(p.glazeOf(nas, next: next), Glaze.next);
    expect(p.glazeOf(falaq, next: next), Glaze.empty);
  });

  test('audio is saved once and then found offline', () async {
    final dir = Directory.systemTemp.createTempSync('audio_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    var downloads = 0;
    final audio = AudioService(
      info: const AudioInfo(
        urlTemplate: 'https://cdn.example/{n}.mp3',
        edition: 'ar.alafasy',
        bitrate: 64,
        reciter: 'R',
        publisher: 'P',
        terms: 'T',
      ),
      baseDir: () async => dir,
      download: (url, file) async {
        downloads++;
        expect(url.toString(), startsWith('https://cdn.example/'));
        await file.writeAsBytes([1, 2, 3]);
      },
    );
    final s = surah(112, 4);
    expect(await audio.savedCount(s), 0);
    final seen = <int>[];
    await audio.saveSurah(s, (n, total) => seen.add(n));
    expect(seen.last, 4);
    expect(await audio.savedCount(s), 4);
    await audio.ensure(s.ayat.first);
    expect(downloads, 4);
    await audio.deleteSurah(s);
    expect(await audio.savedCount(s), 0);
  });
}
