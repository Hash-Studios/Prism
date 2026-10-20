import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/auto_rotate/data/repositories/auto_rotate_repository_impl.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wotd_past_pick.dart';
import 'package:Prism/features/wall_of_the_day/domain/repositories/wall_of_the_day_repository.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:async_wallpaper/pigeon_impl_api.dart' as api;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/file.dart' as cache_file;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _PassRecordGateStore extends InMemoryLocalStore {
  final Completer<void> passRecordWriteStarted = Completer<void>();
  final Completer<void> allowPassRecordWrite = Completer<void>();
  final Completer<void> passRecordDeleteStarted = Completer<void>();
  final Completer<void> allowPassRecordDelete = Completer<void>();
  final Completer<void> ownerTwoConfigWriteCompleted = Completer<void>();
  bool delayPassRecordWrite = false;
  bool delayPassRecordDelete = false;

  @override
  Future<void> set(String key, Object? value) async {
    if (key == PersistenceKeys.settings('autoRotate.passRecord') && delayPassRecordWrite) {
      passRecordWriteStarted.complete();
      await allowPassRecordWrite.future;
    }
    await super.set(key, value);
    if (key == PersistenceKeys.settings(PersistenceKeys.autoRotateChargingOnly) && value == true) {
      ownerTwoConfigWriteCompleted.complete();
    }
  }

  @override
  Future<void> delete(String key) async {
    if (key == PersistenceKeys.settings('autoRotate.passRecord') && delayPassRecordDelete) {
      passRecordDeleteStarted.complete();
      await allowPassRecordDelete.future;
    }
    await super.delete(key);
  }
}

class _MockWalls extends Mock implements PrismWallpaperRepository {}

class _MockWotd extends Mock implements WallOfTheDayRepository {}

class _MockCacheManager extends Mock implements BaseCacheManager {}

PrismWallpaper _wall(String url) => PrismWallpaper(
  core: WallpaperCore(id: url, source: WallpaperSource.prism, fullUrl: url, thumbnailUrl: ''),
);

AppliedWallpaper _applied(String id, String url, DateTime at) =>
    AppliedWallpaper(id: id, source: 'prism', thumbnailUrl: '', fullUrl: url, target: 'home', appliedAt: at);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const String stopChannel = 'dev.flutter.pigeon.async_wallpaper.WallpaperApi.stopWallpaperRotation';
  const String statusChannel = 'dev.flutter.pigeon.async_wallpaper.WallpaperApi.getWallpaperRotationStatus';
  const BasicMessageChannel<Object?> rotationChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.async_wallpaper.WallpaperApi.startWallpaperRotation',
    api.WallpaperApi.pigeonChannelCodec,
  );
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late AutoRotateRepositoryImpl repository;
  late SettingsLocalDataSource settings;
  late _MockWalls walls;
  late _MockWotd wotd;
  late WallpaperHistoryStore history;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    walls = _MockWalls();
    wotd = _MockWotd();
    history = WallpaperHistoryStore(settings);
    repository = AutoRotateRepositoryImpl(settings, walls, wotd, history);
    messenger.setMockMessageHandler(
      stopChannel,
      (ByteData? _) async => const StandardMessageCodec().encodeMessage(<Object?>[true]),
    );
  });

  tearDown(() async {
    await getIt.reset();
    debugDefaultTargetPlatformOverride = null;
    OfflineAssetStore.testOverride = null;
    messenger.setMockMessageHandler(stopChannel, null);
    messenger.setMockMessageHandler(statusChannel, null);
    messenger.setMockDecodedMessageHandler<Object?>(rotationChannel, null);
  });

  test('reports a rejected native stop instead of treating it as stopped', () async {
    messenger.setMockMessageHandler(
      stopChannel,
      (ByteData? _) async => const StandardMessageCodec().encodeMessage(<Object?>[false]),
    );

    expect(await repository.stop(), isFalse);
  });

  test('preserves native status-channel errors', () async {
    messenger.setMockMessageHandler(
      statusChannel,
      (ByteData? _) async =>
          const StandardMessageCodec().encodeMessage(<Object?>['channel-error', 'status unavailable', null]),
    );

    final status = await repository.status();

    expect(status.isRunning, isFalse);
    expect(status.lastError, isNotNull);
  });

  test('saves and loads the trigger, hours and source options', () async {
    const AutoRotateConfig config = AutoRotateConfig(
      enabled: true,
      intervalMinutes: 360,
      target: WallpaperTarget.both,
      shuffle: false,
      source: AutoRotateSource.downloads,
      chargingOnly: true,
    );

    await repository.saveConfig(config);

    expect(await repository.loadConfig(), config);
  });

  test('binds a saved pass to its owner and clears it again', () async {
    final DateTime until = DateTime.utc(2026, 10, 24, 12);
    await repository.saveConfig(AutoRotateConfig(enabled: true, passUntil: until), ownerId: 'owner-1');
    expect((await repository.loadConfig(ownerId: 'owner-1')).passUntil, until);
    expect((await repository.loadConfig(ownerId: 'owner-2')).passUntil, isNull);
    expect((await repository.loadConfig()).passUntil, isNull);

    await repository.saveConfig(const AutoRotateConfig(enabled: true), ownerId: 'owner-2');
    expect((await repository.loadConfig(ownerId: 'owner-1')).passUntil, until);

    await repository.saveConfig(const AutoRotateConfig(enabled: true), ownerId: 'owner-1');
    expect((await repository.loadConfig(ownerId: 'owner-1')).passUntil, isNull);
  });

  test('account cleanup wins over a pass save already in flight', () async {
    final _PassRecordGateStore gatedStore = _PassRecordGateStore();
    gatedStore.delayPassRecordWrite = true;
    settings = SettingsLocalDataSource(gatedStore);
    repository = AutoRotateRepositoryImpl(settings, walls, wotd, history);
    final Future<void> save = repository.saveConfig(
      AutoRotateConfig(passUntil: DateTime.utc(2026, 10, 24)),
      ownerId: 'owner-1',
    );
    await gatedStore.passRecordWriteStarted.future;
    final Future<void> clear = AutoRotateRepositoryImpl.clearPassRecordForUser(settings: settings, ownerId: 'owner-1');

    gatedStore.allowPassRecordWrite.complete();
    await Future.wait(<Future<void>>[save, clear]);

    expect(settings.get<String?>('autoRotate.passRecord'), isNull);
  });

  test('clearing owner one cannot delete owner two’s concurrent pass save', () async {
    final _PassRecordGateStore gatedStore = _PassRecordGateStore();
    settings = SettingsLocalDataSource(gatedStore);
    repository = AutoRotateRepositoryImpl(settings, walls, wotd, history);
    await settings.set(
      'autoRotate.passRecord',
      jsonEncode(<String, Object?>{'ownerId': 'owner-1', 'untilMs': DateTime.utc(2026, 10, 24).millisecondsSinceEpoch}),
    );
    gatedStore.delayPassRecordDelete = true;
    final Future<void> clear = AutoRotateRepositoryImpl.clearPassRecordForUser(settings: settings, ownerId: 'owner-1');
    await gatedStore.passRecordDeleteStarted.future;

    final DateTime ownerTwoPassUntil = DateTime.utc(2026, 11, 1);
    final Future<void> save = repository.saveConfig(
      AutoRotateConfig(chargingOnly: true, passUntil: ownerTwoPassUntil),
      ownerId: 'owner-2',
    );
    await gatedStore.ownerTwoConfigWriteCompleted.future;
    await Future<void>.delayed(Duration.zero);
    gatedStore.allowPassRecordDelete.complete();
    await Future.wait(<Future<void>>[clear, save]);

    expect((await repository.loadConfig(ownerId: 'owner-2')).passUntil, ownerTwoPassUntil);
  });

  test('does not treat a legacy ownerless pass expiry as an entitlement', () async {
    await settings.set('autoRotate.passUntilMs', DateTime.utc(2026, 10, 24).millisecondsSinceEpoch);

    expect((await repository.loadConfig(ownerId: 'owner-1')).passUntil, isNull);
  });

  test('maps the options to plugin triggers', () {
    expect(AutoRotateRepositoryImpl.triggersFor(const AutoRotateConfig()), <aw.WallpaperRotationTrigger>{
      aw.WallpaperRotationTrigger.interval,
    });
    expect(
      AutoRotateRepositoryImpl.triggersFor(const AutoRotateConfig(chargingOnly: true)),
      <aw.WallpaperRotationTrigger>{aw.WallpaperRotationTrigger.charging},
    );
  });

  test('reads cached and total counts from the native status', () async {
    messenger.setMockMessageHandler(
      statusChannel,
      (ByteData? _) async => api.WallpaperApi.pigeonChannelCodec.encodeMessage(<Object?>[
        api.WallpaperRotationStatusData(
          isRunning: true,
          nextRunEpochMs: 5,
          currentIndex: 0,
          cachedCount: 3,
          totalCount: 8,
          effectiveIntervalMinutes: 60,
        ),
      ]),
    );

    final AutoRotateStatus status = await repository.status();

    expect(status.cachedCount, 3);
    expect(status.totalCount, 8);
  });

  test('shows the battery tip only once', () async {
    expect(await repository.consumeBatteryTip(), isTrue);
    expect(await repository.consumeBatteryTip(), isFalse);
  });
  group('sources', () {
    test('protected category, WOTD and signed history resolve only acquired originals by identity', () async {
      final directory = Directory.systemTemp.createTempSync('rotation-identity');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/owned.jpg')..writeAsBytesSync([1]);
      final index = DownloadedWallIndex(settings, ownerId: () => 'alice');
      getIt.registerSingleton<DownloadedWallIndex>(index);
      await index.remember(link: 'https://old.test/owned.jpg', id: 'canonical', source: WallpaperSource.prism);
      const channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
        PrismMediaHostApi.pigeonChannelCodec,
      );
      messenger.setMockDecodedMessageHandler<Object?>(
        channel,
        (_) async => <Object?>[
          DownloadItemsResult(success: true, items: [file.path]),
        ],
      );
      addTearDown(() => messenger.setMockDecodedMessageHandler<Object?>(channel, null));
      const protected = PrismWallpaper(
        core: WallpaperCore(id: 'canonical', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
      );
      const unacquired = PrismWallpaper(
        core: WallpaperCore(id: 'unacquired', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
      );
      when(
        () => walls.fetchByCategory('Space', limit: 40, sourceTag: 'auto_rotate.category'),
      ).thenAnswer((_) async => Result.success([protected, unacquired]));
      when(() => wotd.fetchRecent()).thenAnswer(
        (_) async => Result.success([
          WotdPastPick(date: DateTime.utc(2026), wallpaper: protected),
          WotdPastPick(date: DateTime.utc(2025), wallpaper: unacquired),
        ]),
      );
      await history.record(
        AppliedWallpaper(
          id: 'history',
          wallpaperId: 'canonical',
          source: 'prism',
          thumbnailUrl: '',
          fullUrl: 'https://signed.test/new-token',
          target: 'home',
          appliedAt: DateTime.utc(2026),
        ),
      );
      expect(await repository.loadRemoteUrls(AutoRotateSource.category, category: 'Space'), [file.path]);
      expect(await repository.loadRemoteUrls(AutoRotateSource.wallOfTheDay), [file.path]);
      expect(await repository.loadRemoteUrls(AutoRotateSource.history), [file.path]);
      expect(file.existsSync(), isTrue);
    });

    test('only acquired native files and precise public provider hosts enter native rotation', () async {
      final directory = Directory.systemTemp.createTempSync('rotation-acquired');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/owned.jpg')..writeAsBytesSync([1]);
      const owned = 'https://storage.googleapis.com/private/owned.jpg';
      final index = DownloadedWallIndex(settings, ownerId: () => 'alice');
      getIt.registerSingleton<DownloadedWallIndex>(index);
      await index.remember(link: owned, id: 'canonical', source: WallpaperSource.prism);
      const downloadsChannel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
        PrismMediaHostApi.pigeonChannelCodec,
      );
      messenger.setMockDecodedMessageHandler<Object?>(
        downloadsChannel,
        (_) async => <Object?>[
          DownloadItemsResult(success: true, items: [file.path]),
        ],
      );
      addTearDown(() => messenger.setMockDecodedMessageHandler<Object?>(downloadsChannel, null));
      api.WallpaperRotationConfigData? request;
      messenger.setMockDecodedMessageHandler<Object?>(rotationChannel, (message) async {
        request = (message! as List<Object?>).single! as api.WallpaperRotationConfigData;
        return <Object?>[true];
      });
      expect(
        await repository.start(const AutoRotateConfig(), [
          owned,
          'https://raw.githubusercontent.com/private/original.jpg',
          'https://firebasestorage.googleapis.com/private.jpg',
          'https://images.pexels.com.evil.test/1.jpg',
          'http://images.pexels.com/1.jpg',
          'https://images.pexels.com/1.jpg',
        ]),
        isTrue,
      );
      expect(request!.sources!.map((source) => source!.source), [file.path, 'https://images.pexels.com/1.jpg']);
      expect(await repository.loadAppliedSources(), [file.path, 'https://images.pexels.com/1.jpg']);
      expect(file.existsSync(), isTrue);
    });

    test('legacy applied originals stop before rotate-now and are not exposed for reuse', () async {
      var stops = 0;
      messenger.setMockMessageHandler(stopChannel, (ByteData? _) async {
        stops++;
        return const StandardMessageCodec().encodeMessage(<Object?>[true]);
      });
      await settings.set('autoRotate.appliedSources', jsonEncode(['https://storage.googleapis.com/private.jpg']));
      expect(await repository.rotateNow(), isFalse);
      expect(stops, 1);
      expect(await repository.loadAppliedSources(), isNull);
    });

    test('category asks for 40 reviewed walls of the chosen category and keeps the server order', () async {
      when(() => walls.fetchByCategory('Space', limit: 40, sourceTag: 'auto_rotate.category')).thenAnswer(
        (_) async => Result.success(<PrismWallpaper>[
          _wall('https://images.pexels.com/2.jpg'),
          _wall('https://images.pexels.com/1.jpg'),
        ]),
      );

      final urls = await repository.loadRemoteUrls(AutoRotateSource.category, category: 'Space');

      expect(urls, <String>['https://images.pexels.com/2.jpg', 'https://images.pexels.com/1.jpg']);
      verify(() => walls.fetchByCategory('Space', limit: 40, sourceTag: 'auto_rotate.category')).called(1);
    });

    test('category drops duplicates and urls that are not https', () async {
      when(() => walls.fetchByCategory('Neon', limit: 40, sourceTag: 'auto_rotate.category')).thenAnswer(
        (_) async => Result.success(<PrismWallpaper>[
          _wall('https://images.pexels.com/1.jpg'),
          _wall('https://images.pexels.com/1.jpg'),
          _wall('http://a.test/2.jpg'),
        ]),
      );

      expect(await repository.loadRemoteUrls(AutoRotateSource.category, category: 'Neon'), <String>[
        'https://images.pexels.com/1.jpg',
      ]);
    });

    test('category returns null when the wallpapers cannot be loaded', () async {
      when(
        () => walls.fetchByCategory(
          any(),
          limit: any(named: 'limit'),
          sourceTag: any(named: 'sourceTag'),
        ),
      ).thenAnswer((_) async => Result.error(const ServerFailure('offline')));

      expect(await repository.loadRemoteUrls(AutoRotateSource.category, category: 'Nature'), isNull);
    });

    test('Wall of the Day reads the last 30 picks in archive order', () async {
      when(() => wotd.fetchRecent()).thenAnswer(
        (_) async => Result.success(<WotdPastPick>[
          WotdPastPick(date: DateTime.utc(2026, 5, 2), wallpaper: _wall('https://images.pexels.com/new.jpg')),
          WotdPastPick(date: DateTime.utc(2026, 5), wallpaper: _wall('https://images.pexels.com/old.jpg')),
        ]),
      );

      expect(await repository.loadRemoteUrls(AutoRotateSource.wallOfTheDay), <String>[
        'https://images.pexels.com/new.jpg',
        'https://images.pexels.com/old.jpg',
      ]);
      verify(() => wotd.fetchRecent()).called(1);
    });

    test('Wall of the Day returns null on failure', () async {
      when(() => wotd.fetchRecent()).thenAnswer((_) async => Result.error(const ServerFailure('offline')));

      expect(await repository.loadRemoteUrls(AutoRotateSource.wallOfTheDay), isNull);
    });

    test('history gives unique local paths and https urls in a stable order', () async {
      final DateTime now = DateTime.utc(2026, 5);
      await history.record(_applied('1', 'https://images.pexels.com/b.jpg', now));
      await history.record(_applied('2', 'https://images.pexels.com/a.jpg', now.add(const Duration(hours: 1))));
      await history.record(_applied('3', 'https://images.pexels.com/b.jpg', now.add(const Duration(hours: 2))));
      await history.record(_applied('4', '/storage/local.jpg', now.add(const Duration(hours: 3))));
      await history.record(_applied('6', '/storage/another.jpg', now.add(const Duration(hours: 5))));

      final first = await repository.loadRemoteUrls(AutoRotateSource.history);
      await history.record(_applied('5', 'https://images.pexels.com/a.jpg', now.add(const Duration(hours: 4))));
      final second = await repository.loadRemoteUrls(AutoRotateSource.history);

      expect(first, <String>[
        '/storage/another.jpg',
        '/storage/local.jpg',
        'https://images.pexels.com/a.jpg',
        'https://images.pexels.com/b.jpg',
      ]);
      expect(second, first);
    });

    test('history rotation preserves local files alongside remote URLs', () async {
      api.WallpaperRotationConfigData? request;
      messenger.setMockDecodedMessageHandler<Object?>(rotationChannel, (message) async {
        request = (message! as List<Object?>).single! as api.WallpaperRotationConfigData;
        return <Object?>[true];
      });

      expect(
        await repository.start(const AutoRotateConfig(source: AutoRotateSource.history), <String>[
          '/storage/emulated/0/Prism/wall.jpg',
          'https://w.wallhaven.cc/remote.jpg',
        ]),
        isTrue,
      );
      expect(
        request!.sources!.map((source) => (source!.source, source.sourceType)).toList(),
        <(String?, api.RotationSourceTypeData?)>[
          ('/storage/emulated/0/Prism/wall.jpg', api.RotationSourceTypeData.file),
          ('https://w.wallhaven.cc/remote.jpg', api.RotationSourceTypeData.url),
        ],
      );
    });

    test('temporary and retained cache entries cannot authorize background originals', () async {
      const String temporaryUrl = 'https://images.example/temporary.jpg';
      const String retainedUrl = 'https://images.example/retained.jpg';
      final Directory root = await Directory.systemTemp.createTemp('auto-rotate-retained-');
      addTearDown(() => root.delete(recursive: true));
      final File original = File('${root.path}/original.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff, 0xe0]);
      final File temporary = File('${root.path}/temporary.jpg')..writeAsBytesSync(<int>[0xff, 0xd8, 0xff, 0xe0]);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => root.path,
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
      });
      final cache_file.File cached = await IOFileSystem('rotation-test').createFile('temporary.jpg');
      await cached.writeAsBytes(await temporary.readAsBytes());
      final _MockCacheManager cache = _MockCacheManager();
      when(
        () => cache.getFileFromCache(temporaryUrl),
      ).thenAnswer((_) async => FileInfo(cached, FileSource.Cache, DateTime.utc(2026), temporaryUrl));
      when(() => cache.emptyCache()).thenAnswer((_) async {});
      final OfflineAssetStore assets = OfflineAssetStore(
        directory: Directory('${root.path}/store'),
        cacheManager: cache,
      );
      OfflineAssetStore.testOverride = assets;
      final File retained = await assets.retain(retainedUrl, file: original);
      expect((await assets.lookup(temporaryUrl))?.path, cached.path);
      api.WallpaperRotationConfigData? request;
      messenger.setMockDecodedMessageHandler<Object?>(rotationChannel, (message) async {
        request = (message! as List<Object?>).single! as api.WallpaperRotationConfigData;
        return <Object?>[true];
      });

      expect(
        await repository.start(const AutoRotateConfig(source: AutoRotateSource.history), <String>[
          temporaryUrl,
          retainedUrl,
        ]),
        isFalse,
      );

      expect(request, isNull);
      expect(retained.existsSync(), isTrue);

      await cache.emptyCache();
      when(() => cache.getFileFromCache(temporaryUrl)).thenAnswer((_) async => null);
      expect((await assets.localPaths())[retainedUrl], retained.path);
      expect(
        await repository.start(const AutoRotateConfig(source: AutoRotateSource.history), <String>[
          temporaryUrl,
          retainedUrl,
        ]),
        isFalse,
      );
      expect(request, isNull);
      expect(retained.existsSync(), isTrue);
    });

    test('favourites and downloads are not loaded by the repository', () async {
      expect(await repository.loadRemoteUrls(AutoRotateSource.favourites), isEmpty);
      expect(await repository.loadRemoteUrls(AutoRotateSource.downloads), isEmpty);
    });
  });

  group('config', () {
    test('saves and loads the new sources, the category and the new intervals', () async {
      for (final int minutes in AutoRotateConfig.intervalOptions) {
        for (final AutoRotateSource source in AutoRotateSource.values) {
          final AutoRotateConfig config = AutoRotateConfig(
            enabled: true,
            intervalMinutes: minutes,
            source: source,
            categoryName: 'Cyberpunk',
          );
          await repository.saveConfig(config);
          expect(await repository.loadConfig(), config);
        }
      }
    });

    test('offers 15 minutes, 30 minutes, 3 hours, 3 days and a week', () {
      expect(AutoRotateConfig.intervalOptions, containsAll(<int>[15, 30, 180, 4320, 10080]));
    });

    test('falls back to the default interval for a value that is not offered', () async {
      await settings.set('autoRotate.intervalMinutes', 7);

      expect((await repository.loadConfig()).intervalMinutes, 1440);
    });

    test('the category picker offers the classifier names', () {
      expect(autoRotateCategories, hasLength(18));
      expect(autoRotateCategories, containsAll(<String>['Nature', 'AI Art', '3D Render', 'Galaxy']));
    });
  });
}
