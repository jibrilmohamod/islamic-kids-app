import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

import 'models.dart';

/// Recitation audio, one mp3 per ayah. Files are saved on the device the
/// first time they play (or when a whole surah is downloaded) and play
/// offline from then on.
class AudioService {
  final AudioInfo info;
  final Future<Directory> Function() baseDir;
  final Future<void> Function(Uri url, File target) download;
  AudioPlayer? _p;
  AudioPlayer get _player => _p ??= AudioPlayer();

  AudioService({required this.info, required this.baseDir, Future<void> Function(Uri, File)? download})
      : download = download ?? downloadFile;

  Stream<void> get onComplete => _player.onPlayerComplete;

  Future<Directory> _dir() async {
    final d = Directory('${(await baseDir()).path}/audio/${info.edition}-${info.bitrate}');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> fileFor(Ayah a) async => File('${(await _dir()).path}/${a.n}.mp3');

  Future<bool> isSaved(Ayah a) async => a.n != null && await (await fileFor(a)).exists();

  Future<int> savedCount(Surah s) async {
    var n = 0;
    for (final a in s.ayat) {
      if (await isSaved(a)) n++;
    }
    return n;
  }

  Future<File> ensure(Ayah a) async {
    final n = a.n;
    if (n == null) throw StateError('No audio number for ${a.key}');
    final f = await fileFor(a);
    if (!await f.exists()) await download(info.urlFor(n), f);
    return f;
  }

  /// Saves every ayah of [s], four at a time. [onProgress] gets (saved, total).
  Future<void> saveSurah(Surah s, void Function(int saved, int total) onProgress) async {
    final total = s.ayat.length;
    var saved = 0;
    final queue = List<Ayah>.of(s.ayat);
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final a = queue.removeAt(0);
        await ensure(a);
        saved++;
        onProgress(saved, total);
      }
    }

    await Future.wait(List.generate(4, (_) => worker()));
  }

  Future<void> deleteSurah(Surah s) async {
    for (final a in s.ayat) {
      final f = await fileFor(a);
      if (await f.exists()) await f.delete();
    }
  }

  Future<void> play(Ayah a) async {
    final f = await ensure(a);
    await _player.stop();
    await _player.play(DeviceFileSource(f.path));
  }

  Future<void> stop() async => _p?.stop();

  Future<void> dispose() async => _p?.dispose();
}

/// Downloads to a temp file and renames it, so a cut connection never
/// leaves a broken mp3 that looks saved.
Future<void> downloadFile(Uri url, File target) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  final tmp = File('${target.path}.part');
  try {
    final req = await client.getUrl(url);
    final res = await req.close().timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: url);
    final sink = tmp.openWrite();
    await res.pipe(sink).timeout(const Duration(minutes: 2));
    await tmp.rename(target.path);
  } finally {
    client.close();
    if (await tmp.exists()) await tmp.delete();
  }
}
