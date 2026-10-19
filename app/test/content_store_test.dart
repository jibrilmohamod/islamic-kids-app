// Run: flutter test
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/content_store.dart';

String bundle(String version, {int schema = 1}) => jsonEncode({
      'schemaVersion': schema,
      'bundleVersion': version,
      'languages': ['en'],
      'surahs': [
        {
          'id': 'surah-1',
          'number': 1,
          'name': 'Test',
          'nameAr': 'T',
          'ayat': [
            {'key': '1:1', 'aya': 1, 'arabic': 'A', 'meaning': {}},
          ],
        },
      ],
      'hadith': [],
      'duas': [],
    });

String manifest(String version, String body, {int schema = 1, int? size}) => jsonEncode({
      'schemaVersion': schema,
      'bundleVersion': version,
      'sha256': 'x',
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
    final b = await store({}).loadBest();
    expect(b.version, '20261019000000');
  });

  test('downloads a newer bundle and uses it next launch', () async {
    final newer = bundle('20261101000000');
    final s = store({'v1/manifest.json': manifest('20261101000000', newer), 'v1/bundles/x.json': newer});
    expect(await s.checkForUpdate('20261019000000'), isTrue);
    expect((await s.loadBest()).version, '20261101000000');
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
    expect((await s.loadBest()).version, '20261019000000');
  });

  test('rejects a download whose size does not match', () async {
    final newer = bundle('20261101000000');
    final s = store({'v1/manifest.json': manifest('20261101000000', newer, size: 1), 'v1/bundles/x.json': newer});
    expect(await s.checkForUpdate('20261019000000'), isFalse);
  });

  test('an APK newer than the cache wins', () async {
    File('${dir.path}/bundle.json').writeAsStringSync(bundle('20250101000000'));
    expect((await store({}).loadBest()).version, '20261019000000');
  });

  test('offline is not an error', () async {
    expect(await store({}).checkForUpdate('20261019000000'), isFalse);
  });
}
