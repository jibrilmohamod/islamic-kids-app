import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'models.dart';
import 'mushaf.dart';

/// Schema of the bundle this app version can read. The pipeline and the
/// publish-content function use the same number.
const supportedSchemaVersion = 1;

/// Public, read-only Supabase Storage location. No key needed.
const contentBaseUrl =
    'https://jmczkzlzvwkfbxsiftls.supabase.co/storage/v1/object/public/content/';
const manifestPath = 'v1/manifest.json';

/// The server refuses bundles over 20 MB; so does the app (audit S5).
const maxBundleBytes = 20 * 1024 * 1024;

/// Where recitation audio may come from. A bundle naming any other host is
/// refused, so a tampered bundle cannot send the app elsewhere (audit S7).
const allowedAudioPrefixes = ['https://cdn.islamic.network/quran/audio/'];

/// Content ready to show: the bundle and its mushaf pages, built together
/// off the UI thread.
class LoadedContent {
  final ContentBundle bundle;
  final MushafBook? book;
  const LoadedContent(this.bundle, this.book);
}

class Manifest {
  final int schemaVersion;
  final String bundleVersion;
  final String sha256;
  final int size;
  final String path;

  const Manifest({
    required this.schemaVersion,
    required this.bundleVersion,
    required this.sha256,
    required this.size,
    required this.path,
  });

  factory Manifest.fromJson(Map<String, dynamic> j) => Manifest(
        schemaVersion: (j['schemaVersion'] as num).toInt(),
        bundleVersion: j['bundleVersion'] as String,
        sha256: j['sha256'] as String,
        size: (j['size'] as num).toInt(),
        path: j['path'] as String,
      );
}

typedef Fetch = Future<String> Function(Uri url);

/// Offline-first content: the bundle shipped in the APK is always there; a
/// newer published bundle is downloaded in the background and used from the
/// next launch, so text never changes under a child mid-lesson.
class ContentStore {
  final Future<String> Function() loadAsset;
  final Future<Directory> Function() cacheDir;
  final Fetch fetch;

  ContentStore({required this.loadAsset, required this.cacheDir, Fetch? fetch})
      : fetch = fetch ?? httpGet;

  Future<File> _cachedFile() async => File('${(await cacheDir()).path}/bundle.json');

  /// The newest readable bundle (a cached download if newer than the APK's
  /// own) and its mushaf pages. Decoding 6 MB of JSON and laying out 604
  /// pages takes long enough to freeze a cheap phone, so it runs on a
  /// background isolate (audit F1, F2).
  Future<LoadedContent> loadBest() async {
    final assetRaw = await loadAsset();
    String? cachedRaw;
    try {
      final file = await _cachedFile();
      if (await file.exists()) cachedRaw = await file.readAsString();
    } catch (e) {
      // A bad cache must never stop the app; the asset is used instead.
      debugPrint('Content cache unreadable: $e');
    }
    return _prepareInBackground(assetRaw, cachedRaw);
  }

  /// Checks the manifest and downloads a newer bundle if there is one.
  /// Returns true when a new bundle was saved for the next launch.
  Future<bool> checkForUpdate(String currentVersion) async {
    try {
      final manifest = Manifest.fromJson(
        jsonDecode(await fetch(Uri.parse('$contentBaseUrl$manifestPath'))) as Map<String, dynamic>,
      );
      if (manifest.schemaVersion != supportedSchemaVersion) return false;
      if (manifest.bundleVersion.compareTo(currentVersion) <= 0) return false;

      if (manifest.size > maxBundleBytes) return false;

      final raw = await fetch(Uri.parse('$contentBaseUrl${manifest.path}'));
      // Size, hash and parse on a background isolate (audit S1, F1).
      final ok = await _verifyInBackground(raw, manifest);
      if (!ok) return false;

      // Write to a temp file, then rename: a crash mid-write leaves the old
      // cache intact.
      final file = await _cachedFile();
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(raw, flush: true);
      await tmp.rename(file.path);
      return true;
    } catch (e) {
      debugPrint('Content update skipped: $e');
      return false; // offline, timeout, bad data: try again next launch
    }
  }
}

// Top-level, so the closures sent to the isolate capture only their
// arguments, never a ContentStore and its callbacks.
Future<LoadedContent> _prepareInBackground(String asset, String? cached) =>
    Isolate.run(() => prepareContent(asset, cached));

Future<bool> _verifyInBackground(String raw, Manifest manifest) => Isolate.run(() => _verified(raw, manifest));

/// Whether a downloaded bundle is exactly the one the manifest names.
bool _verified(String raw, Manifest manifest) {
  final bytes = utf8.encode(raw);
  if (bytes.length != manifest.size) return false;
  if (sha256.convert(bytes).toString() != manifest.sha256.toLowerCase()) return false;
  final bundle = parseBundle(raw);
  return bundle != null && bundle.version == manifest.bundleVersion;
}

/// Parses the APK's bundle and an optional cached one, keeps the newer
/// readable one and builds its mushaf. Runs on a background isolate.
LoadedContent prepareContent(String assetRaw, String? cachedRaw) {
  final asset = parseBundle(assetRaw);
  if (asset == null) throw StateError('The bundle in the APK cannot be read');
  var best = asset;
  final cached = cachedRaw == null ? null : parseBundle(cachedRaw);
  if (cached != null && cached.version.compareTo(asset.version) > 0) best = cached;
  return LoadedContent(best, MushafBook.from(best));
}

/// Returns null for anything this app version cannot safely show.
ContentBundle? parseBundle(String raw) {
  try {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['schemaVersion'] != supportedSchemaVersion) return null;
    final b = ContentBundle.fromJson(j);
    if (b.version.isEmpty || b.surahs.isEmpty) return null;
    final audio = b.audio;
    if (audio != null && !allowedAudioPrefixes.any(audio.urlTemplate.startsWith)) return null;
    return b;
  } catch (e) {
    debugPrint('Bundle unreadable: $e');
    return null;
  }
}

Future<String> httpGet(Uri url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await client.getUrl(url);
    final res = await req.close().timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: url);
    if (res.contentLength > maxBundleBytes) throw HttpException('too large', uri: url);
    // Count as it arrives, so a server that lies about the length still
    // cannot fill the phone's memory.
    final body = BytesBuilder(copy: false);
    await for (final chunk in res.timeout(const Duration(seconds: 60))) {
      body.add(chunk);
      if (body.length > maxBundleBytes) throw HttpException('too large', uri: url);
    }
    return utf8.decode(body.takeBytes());
  } finally {
    client.close();
  }
}
