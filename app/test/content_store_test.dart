// Run: flutter test
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/content_store.dart';

String bundle(String version, {int schema = 1, String? audioUrl, List<String> reciterUrls = const []}) => jsonEncode({
      'schemaVersion': schema,
      'bundleVersion': version,
      if (audioUrl != null)
        'audio': {'urlTemplate': audioUrl, 'edition': 'e', 'bitrate': 64, 'reciter': 'R', 'publisher': 'P', 'terms': 'T'},
      if (reciterUrls.isNotEmpty)
        'reciters': [
          for (final (i, u) in reciterUrls.indexed)
            {'urlTemplate': u, 'edition': 'e$i', 'bitrate': 64, 'reciter': 'R$i', 'publisher': 'P', 'terms': 'T'},
        ],
      'languages': ['en'],
      'surahs': [
        {
          'id': 'surah-1',
          'number': 1,
          'name': 'Test',
          'nameAr': 'T',
          'ayat': [
            {'key': '1:1', 'aya': 1, 'arabic': 'A', 'meaning': <String, dynamic>{}},
          ],
        },
      ],
      'hadith': <dynamic>[],
      'duas': <dynamic>[],
    });

String manifest(String version, String body, {int schema = 1, int? size, String? hash}) => jsonEncode({
      'schemaVersion': schema,
      'bundleVersion': version,
      'sha256': hash ?? sha256.convert(utf8.encode(body)).toString(),
      'size': size ?? utf8.encode(body).length,
      'path': 'v1/bundles/x.json',
    });

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('content_store_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  ContentStore store(Map<String, String> server) => ContentStore(
        loadAsset: () async => bundle('20261019000000'),
        cacheDir: () async => dir,
        fetch: (url) async {
          final body = server[url.path.split('/content/').last];
          if (body == null) throw const HttpException('404');
          return body;
        },
      );

  test('uses the APK bundle when nothing is cached', () async {
    final b = (await store({}).loadBest()).bundle;
    expect(b.version, '20261019000000');
  });

  test('downloads a newer bundle and uses it next launch', () async {
    final newer = bundle('20261101000000');
    final s = store({'v1/manifest.json': manifest('20261101000000', newer), 'v1/bundles/x.json': newer});
    expect(await s.checkForUpdate('20261019000000'), isTrue);
    expect((await s.loadBest()).bundle.version, '20261101000000');
  });

  test('ignores an older or equal manifest', () async {
    final same = bundle('20261019000000');
    final s = store({'v1/manifest.json': manifest('20261019000000', same), 'v1/bundles/x.json': same});
    expect(await s.checkForUpdate('20261019000000'), isFalse);
  });

  test('ignores an unknown schema', () async {
    final future = bundle('20270101000000', schema: 2);
    final s = store({'v1/manifest.json': manifest('20270101000000', future, schema: 2), 'v1/bundles/x.json': future});
    expect(await s.checkForUpdate('20261019000000'), isFalse);
    expect((await s.loadBest()).bundle.version, '20261019000000');
  });

  test('rejects a download whose size does not match', () async {
    final newer = bundle('20261101000000');
    final s = store({'v1/manifest.json': manifest('20261101000000', newer, size: 1), 'v1/bundles/x.json': newer});
    expect(await s.checkForUpdate('20261019000000'), isFalse);
  });

  test('an APK newer than the cache wins', () async {
    File('${dir.path}/bundle.json').writeAsStringSync(bundle('20250101000000'));
    expect((await store({}).loadBest()).bundle.version, '20261019000000');
  });

  test('offline is not an error', () async {
    expect(await store({}).checkForUpdate('20261019000000'), isFalse);
  });

  test('rejects a download whose SHA-256 does not match the manifest', () async {
    final newer = bundle('20261101000000');
    final s = store({'v1/manifest.json': manifest('20261101000000', newer, hash: 'ab' * 32), 'v1/bundles/x.json': newer});
    expect(await s.checkForUpdate('20261019000000'), isFalse);
  });

  test('refuses a manifest that announces more than the size limit', () async {
    final newer = bundle('20261101000000');
    final s = store({
      'v1/manifest.json': manifest('20261101000000', newer, size: maxBundleBytes + 1),
      'v1/bundles/x.json': newer,
    });
    expect(await s.checkForUpdate('20261019000000'), isFalse);
  });

  test('a bundle that sends audio to another host is not used', () {
    expect(parseBundle(bundle('1', audioUrl: 'https://cdn.islamic.network/quran/audio/64/ar.alafasy/{n}.mp3')), isNotNull);
    expect(parseBundle(bundle('1', audioUrl: 'http://cdn.islamic.network/quran/audio/64/x/{n}.mp3')), isNull);
    expect(parseBundle(bundle('1', audioUrl: 'https://evil.example/{n}.mp3')), isNull);
  });

  test('every reciter must come from an allowed audio host', () {
    const ok = 'https://cdn.islamic.network/quran/audio/64/ar.alafasy/{n}.mp3';
    const ok2 = 'https://cdn.islamic.network/quran/audio/64/ar.husary/{n}.mp3';
    final good = parseBundle(bundle('1', audioUrl: ok, reciterUrls: [ok, ok2]));
    expect(good!.reciters.map((r) => r.edition), ['e0', 'e1']);
    expect(parseBundle(bundle('1', audioUrl: ok, reciterUrls: [ok, 'https://evil.example/{n}.mp3'])), isNull);
    // A bundle from before the choice existed offers its one reciter.
    expect(parseBundle(bundle('1', audioUrl: ok))!.reciters.single.edition, 'e');
  });
}
