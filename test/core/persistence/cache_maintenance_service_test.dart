// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:Prism/core/persistence/data_sources/app_icons_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/cache_maintenance_service.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _MockImageCache extends Mock implements BaseCacheManager {}

class _MockNotificationsLocal extends Mock implements NotificationsLocalDataSource {}

class _MockFeedCacheLocal extends Mock implements FeedCacheLocalDataSource {}

class _MockAppIconsLocal extends Mock implements AppIconsLocalDataSource {}

class _TestPathProvider extends PathProviderPlatform {
  _TestPathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late CacheMaintenanceService service;
  late _MockImageCache imageCache;
  late PathProviderPlatform originalPaths;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('prism-cache-test-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPathProvider('${root.path}/documents');
    imageCache = _MockImageCache();
    final notifications = _MockNotificationsLocal();
    final feeds = _MockFeedCacheLocal();
    final icons = _MockAppIconsLocal();
    when(() => imageCache.emptyCache()).thenAnswer((_) async {});
    when(() => notifications.clearAll()).thenAnswer((_) async {});
    when(() => notifications.clearLastFetchAtUtc()).thenAnswer((_) async {});
    when(() => feeds.clearAllFeedCaches()).thenAnswer((_) async {});
    when(() => icons.clear()).thenAnswer((_) async {});
    service = CacheMaintenanceService(notifications, feeds, icons, imageCache: imageCache);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    await root.delete(recursive: true);
  });

  test('clears editor scratch files while preserving unrelated files and saved downloads', () async {
    final documents = '${root.path}/documents';
    final scratchFiles = [
      '$documents/images/pic.jpg',
      '$documents/images/picThumb.jpg',
      '$documents/filtered_Amaro_pic.jpg',
      '$documents/filtered___pic.jpg',
    ];
    final retainedFiles = [
      '$documents/session.json',
      '$documents/firestore_telemetry.ndjson',
      '$documents/downloads/saved.jpg',
      '$documents/filtered_notes.txt',
      '$documents/filtered_personal.jpg',
      '${root.path}/outside.jpg',
    ];
    for (final path in [...scratchFiles, ...retainedFiles]) {
      await File(path).create(recursive: true);
      await File(path).writeAsString('keep these bytes');
    }
    final link = Link('$documents/filtered_Link_pic.jpg');
    await link.create('${root.path}/outside.jpg');
    await Link('$documents/images/linked.jpg').create('${root.path}/outside.jpg');

    await service.clearTransientCache();

    for (final path in scratchFiles) {
      expect(await File(path).exists(), isFalse, reason: path);
    }
    expect(await Directory('$documents/images').exists(), isFalse);
    for (final path in retainedFiles) {
      expect(await File(path).readAsString(), 'keep these bytes', reason: path);
    }
    expect(await link.exists(), isTrue);
    await service.clearTransientCache();
    verify(() => imageCache.emptyCache()).called(2);
  });

  test('clearing cache does not create a missing documents directory', () async {
    await service.clearTransientCache();

    expect(await Directory('${root.path}/documents').exists(), isFalse);
    verify(() => imageCache.emptyCache()).called(1);
  });
}
