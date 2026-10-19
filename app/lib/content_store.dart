import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// Schema of the bundle this app version can read. The pipeline and the
/// publish-content function use the same number.
const supportedSchemaVersion = 1;

/// Public, read-only Supabase Storage location. No key needed.
const contentBaseUrl =
    'https://jmczkzlzvwkfbxsiftls.supabase.co/storage/v1/object/public/content/';
const manifestPath = 'v1/manifest.json';

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

  /// The newest readable bundle: cached download if it is newer than the
  /// one in the APK, otherwise the APK's own.
  Future<ContentBundle> loadBest() async {
    final asset = parseBundle(await loadAsset())!;
    try {
      final file = await _cachedFile();
      if (await file.exists()) {
        final cached = parseBundle(await file.readAsString());
        if (cached != null && cached.version.compareTo(asset.version) > 0) return cached;
      }
    } catch (_) {
      // A bad cache must never stop the app; fall through to the asset.
    }
    return asset;
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

      final raw = await fetch(Uri.parse('$contentBaseUrl${manifest.path}'));
      if (utf8.encode(raw).length != manifest.size) return false;
      final bundle = parseBundle(raw);
      if (bundle == null || bundle.version != manifest.bundleVersion) return false;

      // Write to a temp file, then rename: a crash mid-write leaves the old
      // cache intact.
      final file = await _cachedFile();
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(raw, flush: true);
      await tmp.rename(file.path);
      return true;
    } catch (_) {
      return false; // offline, timeout, bad data: try again next launch
    }
  }
}

/// Returns null for anything this app version cannot safely show.
ContentBundle? parseBundle(String raw) {
  try {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['schemaVersion'] != supportedSchemaVersion) return null;
    final b = ContentBundle.fromJson(j);
    if (b.version.isEmpty || b.surahs.isEmpty) return null;
    return b;
  } catch (_) {
    return null;
  }
}

Future<String> httpGet(Uri url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await client.getUrl(url);
    final res = await req.close().timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: url);
    return await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 60));
  } finally {
    client.close();
  }
}
