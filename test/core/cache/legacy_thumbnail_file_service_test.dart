import 'dart:io';

import 'package:Prism/core/cache/legacy_thumbnail_file_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const raw = 'https://raw.githubusercontent.com/owner/walls/master/thumb_wall.jpg';
  const proxy = 'https://prismwalls.com/api/legacy-thumbs/master/thumb_wall.jpg';

  test('a blocked raw host does not prevent a legacy thumbnail download', () async {
    final requests = <String>[];
    final service = LegacyThumbnailFileService(
      owner: 'owner',
      repo: 'walls',
      httpClient: MockClient((request) async {
        requests.add(request.url.toString());
        if (request.url.host == 'raw.githubusercontent.com') throw const SocketException('ISP blocked GitHub raw');
        return http.Response.bytes(<int>[1, 2, 3], 200);
      }),
    );
    final response = await service.get(raw);
    expect(await response.content.expand((bytes) => bytes).toList(), <int>[1, 2, 3]);
    expect(requests, <String>[proxy]);
  });

  test('the proxy preserves encoded filenames and accepts owner case differences', () async {
    final requests = <String>[];
    final service = LegacyThumbnailFileService(
      owner: 'owner',
      repo: 'walls',
      httpClient: MockClient((request) async {
        requests.add(request.url.toString());
        return http.Response('', 200);
      }),
    );
    await service.get('https://raw.githubusercontent.com/OWNER/walls/master/folder/thumb_a%20b.jpg');
    expect(requests, <String>['https://prismwalls.com/api/legacy-thumbs/master/folder/thumb_a%20b.jpg']);
  });

  test('other providers, originals, and malformed legacy paths are not rewritten', () async {
    final requests = <String>[];
    final service = LegacyThumbnailFileService(
      owner: 'owner',
      repo: 'walls',
      httpClient: MockClient((request) async {
        requests.add(request.url.toString());
        return http.Response('', 200);
      }),
    );
    for (final url in <String>[
      raw.replaceFirst('thumb_wall', 'wall'),
      raw.replaceFirst('/owner/', '/attacker/'),
      raw.replaceFirst('/walls/', '/other/'),
      raw.replaceFirst('https:', 'http:'),
      raw.replaceFirst('.com/', '.com:8443/'),
      raw.replaceFirst('.com/', '.com:443/'),
      raw.replaceFirst('raw.githubusercontent.com', 'raw.githubusercontent.com.evil.test'),
      raw.replaceFirst('https://', 'https://user@'),
      '$raw?token=secret',
      '$raw#fragment',
      raw.replaceFirst('/master/', '/master//'),
      raw.replaceFirst('/master/', '/master/../'),
      raw.replaceFirst('/master/', '/master/%2e%2e/'),
      raw.replaceFirst('/master/', '/master/%2f/'),
      raw.replaceFirst('/master/', '/master/%5c/'),
      raw.replaceFirst('/master/', '/master/%00/'),
      raw.replaceFirst('/master/', '/master/%252f/'),
      'https://img.prismwalls.com/previews/abc.img',
      'https://images.pexels.com/photos/1/preview.jpg',
      'https://th.wallhaven.cc/lg/12/123.jpg',
    ]) {
      await service.get(url);
      expect(requests.last, Uri.parse(url).toString(), reason: url);
    }
  });

  test('missing repository configuration leaves requests unchanged', () async {
    final service = LegacyThumbnailFileService(
      owner: '',
      repo: '',
      httpClient: MockClient((request) async {
        expect(request.url.toString(), raw);
        return http.Response('', 200);
      }),
    );
    await service.get(raw);
  });

  test('rewritten requests drop source credentials and validators', () async {
    final requests = <http.Request>[];
    final service = LegacyThumbnailFileService(
      owner: 'owner',
      repo: 'walls',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('', 200);
      }),
    );
    const headers = <String, String>{'authorization': 'Bearer source-token', 'if-none-match': 'old-github-etag'};
    await service.get(raw, headers: headers);
    expect(requests.last.headers, isNot(contains('authorization')));
    expect(requests.last.headers, isNot(contains('if-none-match')));
    await service.get('https://images.pexels.com/photos/1/preview.jpg', headers: headers);
    expect(requests.last.headers['authorization'], 'Bearer source-token');
    expect(requests.last.headers['if-none-match'], 'old-github-etag');
  });

  test('cache hits and retry eviction still use the stored raw URL', () async {
    final directory = await Directory.systemTemp.createTemp('legacy-thumb-cache-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => directory.path,
    );
    var requests = 0;
    final cache = CacheManager(
      Config(
        'legacy-thumb-test',
        repo: JsonCacheInfoRepository(path: '${directory.path}/cache.json'),
        fileService: LegacyThumbnailFileService(
          owner: 'owner',
          repo: 'walls',
          httpClient: MockClient((request) async {
            expect(request.url.toString(), proxy);
            requests++;
            return http.Response.bytes(
              <int>[1, 2, 3],
              200,
              headers: <String, String>{'content-type': 'image/jpeg', 'cache-control': 'public, max-age=86400'},
            );
          }),
        ),
      ),
    );
    try {
      await cache.putFile(raw, Uint8List.fromList(<int>[9]), maxAge: const Duration(days: 1));
      expect(await (await cache.getSingleFile(raw)).readAsBytes(), <int>[9]);
      expect(requests, 0);
      await cache.removeFile(raw);
      await cache.getSingleFile(raw);
      expect(await cache.getFileFromCache(raw), isNotNull);
      expect(await cache.getFileFromCache(proxy), isNull);
      expect(await (await cache.getSingleFile(raw)).readAsBytes(), <int>[1, 2, 3]);
      expect(requests, 1);
      await cache.removeFile(raw);
      expect(await cache.getFileFromCache(raw), isNull);
      await cache.getSingleFile(raw);
      expect(requests, 2);
    } finally {
      await cache.dispose();
      await directory.delete(recursive: true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
    }
  });
}
