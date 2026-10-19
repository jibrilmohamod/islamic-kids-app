import 'dart:io';

import 'models.dart';

/// Recitation files, one mp3 per ayah. Files are saved on the device the
/// first time they play (or when a whole surah is downloaded) and play
/// offline from then on. Playing them is [Recitation]'s job.
class AudioService {
  final AudioInfo info;
  final Future<Directory> Function() baseDir;
  final Future<void> Function(Uri url, File target) download;

  AudioService({required this.info, required this.baseDir, Future<void> Function(Uri, File)? download})
      : download = download ?? downloadFile;

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

  /// Every saved ayah number and its file size, from one folder listing.
  Future<Map<int, int>> savedFiles() async {
    final out = <int, int>{};
    final dir = await _dir();
    await for (final e in dir.list()) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.last;
      if (!name.endsWith('.mp3')) continue;
      final n = int.tryParse(name.substring(0, name.length - 4));
      if (n != null) out[n] = await e.length();
    }
    return out;
  }

  final Map<int, Future<File>> _inFlight = {};

  /// The saved file for [a], fetching it first if needed. A download already
  /// running for the same ayah (recitation and "save surah" can overlap) is
  /// shared rather than started twice into the same temp file.
  Future<File> ensure(Ayah a) {
    final n = a.n;
    if (n == null) return Future.error(StateError('No audio number for ${a.key}'));
    return _inFlight[n] ??= _fetch(a, n).whenComplete(() => _inFlight.remove(n));
  }

  Future<File> _fetch(Ayah a, int n) async {
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
