import 'dart:io';

import 'package:Prism/core/persistence/data_sources/app_icons_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/cache_maintenance_service.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockImageCache extends Mock implements BaseCacheManager {}

class _MockNotificationsLocal extends Mock implements NotificationsLocalDataSource {}

class _MockFeedCacheLocal extends Mock implements FeedCacheLocalDataSource {}

class _MockAppIconsLocal extends Mock implements AppIconsLocalDataSource {}

class _MockDirectory extends Mock implements Directory {}

class _MockFile extends Mock implements File {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late CacheMaintenanceService service;
  late _MockImageCache imageCache;
  late _MockImageCache thumbnailCache;
  late _MockNotificationsLocal notifications;
  late _MockFeedCacheLocal feeds;
  late _MockAppIconsLocal icons;
  late bool failDocumentsProvider;
  late _MockDirectory documents;
  late Future<File> Function() createScratchFile;
  late Directory Function(String) directoryOverride;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('prism-cache-test-');
    createScratchFile = () async {
      final file = File('${root.path}/documents/filtered_retry_pic.jpg');
      await file.create(recursive: true);
      return file;
    };
    directoryOverride = (directoryPath) =>
        directoryPath == '${root.path}/documents' ? documents : Directory(directoryPath);
    failDocumentsProvider = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, (
      call,
    ) async {
      if (failDocumentsProvider) throw PlatformException(code: 'documents_unavailable');
      return call.method == 'getTemporaryDirectory' ? '${root.path}/temp' : '${root.path}/documents';
    });
    imageCache = _MockImageCache();
    thumbnailCache = _MockImageCache();
    notifications = _MockNotificationsLocal();
    feeds = _MockFeedCacheLocal();
    icons = _MockAppIconsLocal();
    when(() => imageCache.emptyCache()).thenAnswer((_) async {});
    when(() => thumbnailCache.emptyCache()).thenAnswer((_) async {});
    when(() => notifications.clearAll()).thenAnswer((_) async {});
    when(() => notifications.clearLastFetchAtUtc()).thenAnswer((_) async {});
    when(() => feeds.clearAllFeedCaches()).thenAnswer((_) async {});
    when(() => icons.clear()).thenAnswer((_) async {});
    service = CacheMaintenanceService(
      notifications,
      feeds,
      icons,
      imageCache: imageCache,
      thumbnailCache: thumbnailCache,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      null,
    );
    await root.delete(recursive: true);
  });

  test('clears editor scratch files while preserving unrelated files and saved downloads', () async {
    final documents = '${root.path}/documents';
    final scratchFiles = [
      '$documents/images/pic.jpg',
      '$documents/images/picThumb.jpg',
      '$documents/filtered_Amaro_pic.jpg',
      '$documents/filtered___pic.jpg',
      '$documents/filtered__pic.jpg',
    ];
    final retainedFiles = [
      '$documents/session.json',
      '$documents/firestore_telemetry.ndjson',
      '$documents/downloads/saved.jpg',
      '$documents/filtered_notes.txt',
      '$documents/filtered_personal.jpg',
      '$documents/filtered_pic.jpg',
      '${root.path}/temp/prism_edit/source_active/source.img',
      '${root.path}/outside.jpg',
    ];
    for (final path in [...scratchFiles, ...retainedFiles]) {
      await File(path).create(recursive: true);
      await File(path).writeAsString('keep these bytes');
    }
    final link = Link('$documents/filtered_Link_pic.jpg');
    await link.create('${root.path}/outside.jpg');
    await Link('$documents/images/linked.jpg').create('${root.path}/outside.jpg');
    final linkedDirectory = '${root.path}/linked-outside';
    await Directory(linkedDirectory).create();
    await File('$linkedDirectory/keep.jpg').writeAsString('outside bytes');
    await Link('$documents/images/linked-directory').create(linkedDirectory);

    await service.clearTransientCache();

    for (final path in scratchFiles) {
      expect(await File(path).exists(), isFalse, reason: path);
    }
    expect(await Directory('$documents/images').exists(), isFalse);
    for (final path in retainedFiles) {
      expect(await File(path).readAsString(), 'keep these bytes', reason: path);
    }
    expect(await File('$linkedDirectory/keep.jpg').readAsString(), 'outside bytes');
    expect(await link.exists(), isTrue);
    await service.clearTransientCache();
    verify(() => imageCache.emptyCache()).called(2);
    verify(() => thumbnailCache.emptyCache()).called(2);
  });

  test('clearing cache does not create a missing documents directory', () async {
    await service.clearTransientCache();

    expect(await Directory('${root.path}/documents').exists(), isFalse);
    verify(() => imageCache.emptyCache()).called(1);
    verify(() => thumbnailCache.emptyCache()).called(1);
  });

  test('continues deleting sibling scratch files after one deletion fails', () async {
    final failedImages = _MockDirectory();
    final failedFile = _MockFile();
    final nextFile = File('${root.path}/documents/filtered_next_pic.jpg')
      ..createSync(recursive: true)
      ..writeAsStringSync('scratch');
    when(() => failedImages.path).thenReturn('${root.path}/documents/images');
    when(() => failedImages.delete(recursive: true)).thenThrow(const FileSystemException('locked'));
    when(() => failedFile.path).thenReturn('${root.path}/documents/filtered_failed_pic.jpg');
    when(() => failedFile.delete()).thenThrow(const FileSystemException('locked'));
    documents = _MockDirectory();
    when(() => documents.exists()).thenAnswer((_) async => true);
    when(
      () => documents.list(followLinks: false),
    ).thenAnswer((_) => Stream<FileSystemEntity>.fromIterable([failedImages, failedFile, nextFile]));

    await IOOverrides.runZoned(
      service.clearTransientCache,
      createDirectory: (path) => path == '${root.path}/documents' ? documents : Directory(path),
    );

    expect(await nextFile.exists(), isFalse);
    verify(() => failedImages.delete(recursive: true)).called(1);
    verify(() => failedFile.delete()).called(1);
    verify(() => notifications.clearAll()).called(1);
  });

  test('does not throw when the documents path provider fails', () async {
    failDocumentsProvider = true;

    await expectLater(service.clearTransientCache(), completes);
    final scratchFile = await createScratchFile();
    failDocumentsProvider = false;
    await service.clearTransientCache();

    expect(await scratchFile.exists(), isFalse);
    verify(() => notifications.clearAll()).called(2);
  });

  test('does not throw when checking documents existence fails', () async {
    final realDocuments = Directory('${root.path}/documents');
    documents = _MockDirectory();
    var failOnce = true;
    when(() => documents.exists()).thenAnswer((_) {
      if (failOnce) {
        failOnce = false;
        throw const FileSystemException('documents unavailable');
      }
      return realDocuments.exists();
    });
    when(() => documents.list(followLinks: false)).thenAnswer((_) => realDocuments.list(followLinks: false));

    final scratchFile = await createScratchFile();
    await IOOverrides.runZoned(service.clearTransientCache, createDirectory: directoryOverride);
    await IOOverrides.runZoned(service.clearTransientCache, createDirectory: directoryOverride);

    expect(await scratchFile.exists(), isFalse);
    verify(() => notifications.clearAll()).called(2);
  });

  test('does not throw when listing documents fails', () async {
    final realDocuments = Directory('${root.path}/documents');
    documents = _MockDirectory();
    when(() => documents.exists()).thenAnswer((_) async => true);
    var failOnce = true;
    when(() => documents.list(followLinks: false)).thenAnswer((_) {
      if (failOnce) {
        failOnce = false;
        return Stream.error(const FileSystemException('documents unavailable'));
      }
      return realDocuments.list(followLinks: false);
    });

    final scratchFile = await createScratchFile();
    await IOOverrides.runZoned(service.clearTransientCache, createDirectory: directoryOverride);
    await IOOverrides.runZoned(service.clearTransientCache, createDirectory: directoryOverride);

    expect(await scratchFile.exists(), isFalse);
    verify(() => notifications.clearAll()).called(2);
  });

  for (final stage in [
    'image cache',
    'thumbnail cache',
    'notifications',
    'notification timestamp',
    'feed cache',
    'app icons',
  ]) {
    test('continues clearing caches and legacy scratch after $stage fails, then retries', () async {
      var failOnce = true;
      final clear = switch (stage) {
        'image cache' => imageCache.emptyCache,
        'thumbnail cache' => thumbnailCache.emptyCache,
        'notifications' => notifications.clearAll,
        'notification timestamp' => notifications.clearLastFetchAtUtc,
        'feed cache' => feeds.clearAllFeedCaches,
        _ => icons.clear,
      };
      when(() => clear()).thenAnswer((_) async {
        if (failOnce) {
          failOnce = false;
          throw StateError('$stage failed');
        }
      });

      final scratchFile = await createScratchFile();
      await service.clearTransientCache();

      expect(await scratchFile.exists(), isFalse);
      verify(() => imageCache.emptyCache()).called(1);
      verify(() => thumbnailCache.emptyCache()).called(1);
      verify(() => notifications.clearAll()).called(1);
      verify(() => notifications.clearLastFetchAtUtc()).called(1);
      verify(() => feeds.clearAllFeedCaches()).called(1);
      verify(() => icons.clear()).called(1);

      final retryScratchFile = await createScratchFile();
      await service.clearTransientCache();
      expect(await retryScratchFile.exists(), isFalse);
    });
  }

  test('preserves top-level scratch-name symlinks and wrong-type entries', () async {
    final documentsPath = '${root.path}/documents';
    final outside = '${root.path}/outside';
    await Directory(documentsPath).create(recursive: true);
    await Directory(outside).create();
    final outsideFile = File('$outside/keep.jpg')..writeAsStringSync('keep');
    final imagesLink = Link('$documentsPath/images');
    await imagesLink.create(outside);
    final brokenLink = Link('$documentsPath/filtered_broken_pic.jpg');
    await brokenLink.create('${root.path}/missing');
    final wrongType = Directory('$documentsPath/filtered_directory_pic.jpg')..createSync(recursive: true);

    await service.clearTransientCache();

    expect(await Link(imagesLink.path).exists(), isTrue);
    expect(await outsideFile.readAsString(), 'keep');
    expect(await FileSystemEntity.type(brokenLink.path, followLinks: false), FileSystemEntityType.link);
    expect(await wrongType.exists(), isTrue);
  });
}
