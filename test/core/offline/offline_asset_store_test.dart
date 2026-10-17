import 'dart:async';
import 'dart:io';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/file.dart' as cache_file;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCacheManager extends Mock implements BaseCacheManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Directory assets;
  late _MockCacheManager cache;

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (_) async => root.path,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('prism-offline-assets-');
    assets = Directory('${root.path}/retained');
    cache = _MockCacheManager();
    when(() => cache.getFileFromCache(any())).thenAnswer((_) async => null);
  });

  Future<cache_file.File> cacheFile(File source, String name) async {
    final cached = await IOFileSystem(
      'prism-offline-test',
    ).createFile('${DateTime.now().microsecondsSinceEpoch}-$name');
    await cached.writeAsBytes(await source.readAsBytes());
    return cached;
  }

  tearDown(() async {
    await root.delete(recursive: true);
    OfflineAssetStore.testOverride = null;
  });

  test('retains a flushed copy that resolves after a store restart', () async {
    final source = File('${root.path}/download.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff, 0xe0]);
    final store = OfflineAssetStore(directory: assets, cacheManager: cache);
    final saved = await store.retain('wall-1', file: source);
    source.writeAsBytesSync(<int>[9]);

    final restarted = OfflineAssetStore(directory: assets, cacheManager: cache);

    expect(await restarted.resolve('wall-1', allowNetwork: false).then((file) => file.readAsBytes()), <int>[
      0xff,
      0xd8,
      0xff,
      0xe0,
    ]);
    expect(saved.existsSync(), isTrue);
    expect(await restarted.storedBytes, 4);
    expect(await restarted.localPaths(), <String, String>{'wall-1': saved.path});
  });

  test('concurrent retains of the same source create one saved copy', () async {
    final source = File('${root.path}/deduplicated.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff]);
    final store = OfflineAssetStore(directory: assets, cacheManager: cache);

    final retained = await Future.wait(<Future<File>>[
      store.retain('wall-deduplicated', file: source),
      store.retain('wall-deduplicated', file: source),
    ]);

    expect(retained[0].path, retained[1].path);
    expect(await Directory('${assets.path}/assets').list().length, 1);
  });

  test('rejects a retain that exceeds the byte budget without evicting saved content', () async {
    final small = File('${root.path}/small.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff]);
    final large = File('${root.path}/large.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff, 0xe0]);
    final store = OfflineAssetStore(directory: assets, cacheManager: cache, maxRetainedBytes: 5);
    final retained = await store.retain('first', file: small);

    await expectLater(store.retain('second', file: large), throwsA(isA<OfflineAssetStoreLimitException>()));

    expect(await retained.readAsBytes(), <int>[0xff, 0xd8, 0xff]);
    expect(await store.lookup('second'), isNull);
    expect(await store.storedBytes, 3);
  });

  test('uses valid stale full-cache bytes before considering the network', () async {
    final stale = File('${root.path}/stale.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff]);
    final cachedStale = await cacheFile(stale, 'stale.jpg');
    when(
      () => cache.getFileFromCache('https://example.test/wall.jpg'),
    ).thenAnswer((_) async => FileInfo(cachedStale, FileSource.Cache, DateTime(2000), 'https://example.test/wall.jpg'));
    final store = OfflineAssetStore(directory: assets, cacheManager: cache);

    final resolved = await store.resolve('https://example.test/wall.jpg', allowNetwork: false);

    expect(await resolved.readAsBytes(), <int>[0xff, 0xd8, 0xff]);
    verifyNever(() => cache.getSingleFile(any()));
    expect(await store.localPaths(), isEmpty);
  });

  test('retaining a source repairs a missing manifest file before using stale cache bytes', () async {
    const source = 'https://example.test/missing-retained.jpg';
    final stale = File('${root.path}/stale-retained.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff]);
    final cachedStale = await cacheFile(stale, 'stale-retained.jpg');
    when(
      () => cache.getFileFromCache(source),
    ).thenAnswer((_) async => FileInfo(cachedStale, FileSource.Cache, DateTime(2000), source));
    await DurableJsonStore(
      'asset_manifest',
      directory: assets,
    ).write(source, <String, Object?>{'file': 'assets/no-longer-there.asset', 'bytes': 3});
    final store = OfflineAssetStore(directory: assets, cacheManager: cache);

    final retained = await store.retain(source).timeout(const Duration(seconds: 10));

    expect(await retained.readAsBytes(), <int>[0xff, 0xd8, 0xff]);
    expect(await store.localPaths(), <String, String>{source: retained.path});
  });

  test('manifest paths stay relative when the app support root moves', () async {
    final source = File('${root.path}/portable.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff]);
    final store = OfflineAssetStore(directory: assets, cacheManager: cache);
    await store.retain('wall-portable', file: source);
    final manifest = DurableJsonStore('asset_manifest', directory: assets);
    expect((await manifest.read('wall-portable'))!['file'], startsWith('assets/'));
    final movedRoot = Directory('${root.path}/moved-offline-assets');
    await assets.rename(movedRoot.path);

    final restarted = OfflineAssetStore(directory: movedRoot, cacheManager: cache);
    final file = await restarted.resolve('wall-portable', allowNetwork: false);

    expect(file.path, startsWith(movedRoot.path));
    expect(await file.readAsBytes(), <int>[0xff, 0xd8, 0xff]);
  });

  test('startup sweep removes abandoned part and orphan asset files', () async {
    final assetFiles = Directory('${assets.path}/assets')..createSync(recursive: true);
    final part = File('${assetFiles.path}/interrupted.asset.part')..writeAsBytesSync(<int>[1]);
    final orphan = File('${assetFiles.path}/orphan.asset')..writeAsBytesSync(<int>[2]);
    final store = OfflineAssetStore(directory: assets, cacheManager: cache);

    expect(await store.localPaths(), isEmpty);

    expect(await part.exists(), isFalse);
    expect(await orphan.exists(), isFalse);
  });

  test('rejects invalid image bytes without leaving a partial file or manifest record', () async {
    final invalid = File('${root.path}/not-an-image.jpg')..writeAsBytesSync(<int>[1, 2, 3, 4]);
    final store = OfflineAssetStore(directory: assets, cacheManager: cache);

    await expectLater(store.retain('invalid', file: invalid), throwsA(isA<FormatException>()));

    expect(await store.lookup('invalid'), isNull);
    expect(await Directory('${assets.path}/assets').exists(), isFalse);
  });

  test('failed persistence does not report success or poison a later retain', () async {
    final blocked = File('${root.path}/blocked-offline-root')..writeAsStringSync('not a directory');
    final source = File('${root.path}/recoverable.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff]);
    final store = OfflineAssetStore(directory: Directory(blocked.path), cacheManager: cache);

    await expectLater(store.retain('recoverable', file: source), throwsA(isA<FileSystemException>()));
    blocked.deleteSync();
    Directory(blocked.path).createSync();

    final retained = await store.retain('recoverable', file: source);

    expect(await retained.exists(), isTrue);
    expect(await store.localPaths(), contains('recoverable'));
  });

  test('remove wins over a retain waiting for network resolution', () async {
    const source = 'https://example.test/pending-remove.jpg';
    final downloaded = File('${root.path}/pending-remove.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff]);
    final resolution = Completer<cache_file.File>();
    when(() => cache.getSingleFile(source)).thenAnswer((_) => resolution.future);
    final store = OfflineAssetStore(directory: assets, cacheManager: cache);
    final pendingRetain = store.retain(source);

    await store.remove(source);
    resolution.complete(await cacheFile(downloaded, 'pending-remove.jpg'));

    await expectLater(pendingRetain, throwsA(isA<OfflineAssetRetainCancelledException>()));
    expect(await store.lookup(source), isNull);
    final retainedAgain = await store.retain(source, file: downloaded);
    expect(await retainedAgain.exists(), isTrue);
  });

  test('clearRetained wins over retains waiting for network resolution', () async {
    const source = 'https://example.test/pending-clear.jpg';
    final downloaded = File('${root.path}/pending-clear.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff]);
    final resolution = Completer<cache_file.File>();
    when(() => cache.getSingleFile(source)).thenAnswer((_) => resolution.future);
    final store = OfflineAssetStore(directory: assets, cacheManager: cache);
    final pendingRetain = store.retain(source);

    await store.clearRetained();
    resolution.complete(await cacheFile(downloaded, 'pending-clear.jpg'));

    await expectLater(pendingRetain, throwsA(isA<OfflineAssetRetainCancelledException>()));
    expect(await store.localPaths(), isEmpty);
    expect(await store.storedBytes, 0);
  });

  test('asset-count capacity rejects new content instead of evicting retained files', () async {
    final first = File('${root.path}/first-at-capacity.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff]);
    final second = File('${root.path}/second-at-capacity.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff]);
    final store = OfflineAssetStore(directory: assets, cacheManager: cache, maxRetainedAssets: 1);
    final retained = await store.retain('first', file: first);

    await expectLater(store.retain('second', file: second), throwsA(isA<OfflineAssetStoreLimitException>()));

    expect(await retained.exists(), isTrue);
    expect(await store.localPaths(), hasLength(1));
  });

  test('repairs a retained manifest entry whose file was deleted', () async {
    final original = File('${root.path}/original.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff]);
    final store = OfflineAssetStore(directory: assets, cacheManager: cache);
    final saved = await store.retain('wall-2', file: original);
    await saved.delete();

    expect(await store.lookup('wall-2'), isNull);
    expect(await store.localPaths(), isEmpty);
    expect(await store.storedBytes, 0);
  });

  test('rejects a manifest path outside the retained root', () async {
    final outside = File('${root.path}/outside.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff]);
    final manifest = DurableJsonStore('asset_manifest', directory: assets);
    await manifest.write('wall-traversal', <String, Object?>{'file': '../outside.jpg', 'bytes': 3});
    final store = OfflineAssetStore(directory: assets, cacheManager: cache);

    expect(await store.lookup('wall-traversal'), isNull);
    expect(await outside.exists(), isTrue);
    expect(await manifest.read('wall-traversal'), isNull);
  });

  test('does not follow a symlinked assets directory outside the retained root', () async {
    final outside = Directory('${root.path}/outside-assets')..createSync();
    final external = File('${outside.path}/external.asset')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff]);
    await assets.create(recursive: true);
    final assetDirectory = Link('${assets.path}/assets');
    await assetDirectory.create(outside.path);
    final manifest = DurableJsonStore('asset_manifest', directory: assets);
    await manifest.write('external', <String, Object?>{'file': 'assets/external.asset', 'bytes': 3});
    final store = OfflineAssetStore(directory: assets, cacheManager: cache);

    expect(await store.lookup('external'), isNull);
    final image = File('${root.path}/symlink-save.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff]);
    await expectLater(store.retain('symlink-save', file: image), throwsA(isA<FileSystemException>()));
    expect(await external.exists(), isTrue);
  });

  test('a retained file must match its manifest byte count', () async {
    final assetFiles = Directory('${assets.path}/assets')..createSync(recursive: true);
    final retained = File('${assetFiles.path}/retained.asset')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff]);
    final manifest = DurableJsonStore('asset_manifest', directory: assets);
    await manifest.write('wall-size', <String, Object?>{'file': 'assets/retained.asset', 'bytes': 4});
    final store = OfflineAssetStore(directory: assets, cacheManager: cache);

    expect(await store.lookup('wall-size'), isNull);
    expect(await retained.exists(), isFalse);
    expect(await manifest.read('wall-size'), isNull);
  });

  test('does not report empty or unreadable cached files as successful resolution', () async {
    final empty = File('${root.path}/empty.jpg')..createSync();
    final cachedEmpty = await cacheFile(empty, 'empty.jpg');
    when(() => cache.getFileFromCache('https://example.test/empty.jpg')).thenAnswer(
      (_) async => FileInfo(cachedEmpty, FileSource.Cache, DateTime(2000), 'https://example.test/empty.jpg'),
    );
    when(() => cache.getSingleFile('https://example.test/empty.jpg')).thenThrow(const SocketException('offline'));
    final store = OfflineAssetStore(directory: assets, cacheManager: cache);

    await expectLater(store.resolve('https://example.test/empty.jpg'), throwsA(isA<SocketException>()));
  });

  test('remove and clearRetained only remove explicitly retained content', () async {
    final first = File('${root.path}/first.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff]);
    final second = File('${root.path}/second.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff, 0xe0]);
    final store = OfflineAssetStore(directory: assets, cacheManager: cache);
    final firstSaved = await store.retain('first', file: first);
    final secondSaved = await store.retain('second', file: second);

    await store.remove('first');
    expect(await firstSaved.exists(), isFalse);
    expect(await secondSaved.exists(), isTrue);
    await store.clearRetained();
    expect(await secondSaved.exists(), isFalse);
    expect(await store.storedBytes, 0);
  });
}
