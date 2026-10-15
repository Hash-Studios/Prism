import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/auto_rotate/data/repositories/auto_rotate_repository_impl.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wotd_past_pick.dart';
import 'package:Prism/features/wall_of_the_day/domain/repositories/wall_of_the_day_repository.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:async_wallpaper/pigeon_impl_api.dart' as api;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockWalls extends Mock implements PrismWallpaperRepository {}

class _MockWotd extends Mock implements WallOfTheDayRepository {}

PrismWallpaper _wall(String url) => PrismWallpaper(
  core: WallpaperCore(id: url, source: WallpaperSource.prism, fullUrl: url, thumbnailUrl: ''),
);

AppliedWallpaper _applied(String id, String url, DateTime at) =>
    AppliedWallpaper(id: id, source: 'prism', thumbnailUrl: '', fullUrl: url, target: 'home', appliedAt: at);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const String stopChannel = 'dev.flutter.pigeon.async_wallpaper.WallpaperApi.stopWallpaperRotation';
  const String statusChannel = 'dev.flutter.pigeon.async_wallpaper.WallpaperApi.getWallpaperRotationStatus';
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
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMessageHandler(stopChannel, null);
    messenger.setMockMessageHandler(statusChannel, null);
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
    test('category asks for 40 reviewed walls of the chosen category and keeps the server order', () async {
      when(() => walls.fetchByCategory('Space', limit: 40, sourceTag: 'auto_rotate.category')).thenAnswer(
        (_) async => Result.success(<PrismWallpaper>[_wall('https://a.test/2.jpg'), _wall('https://a.test/1.jpg')]),
      );

      final urls = await repository.loadRemoteUrls(AutoRotateSource.category, category: 'Space');

      expect(urls, <String>['https://a.test/2.jpg', 'https://a.test/1.jpg']);
      verify(() => walls.fetchByCategory('Space', limit: 40, sourceTag: 'auto_rotate.category')).called(1);
    });

    test('category drops duplicates and urls that are not https', () async {
      when(() => walls.fetchByCategory('Neon', limit: 40, sourceTag: 'auto_rotate.category')).thenAnswer(
        (_) async => Result.success(<PrismWallpaper>[
          _wall('https://a.test/1.jpg'),
          _wall('https://a.test/1.jpg'),
          _wall('http://a.test/2.jpg'),
        ]),
      );

      expect(await repository.loadRemoteUrls(AutoRotateSource.category, category: 'Neon'), <String>[
        'https://a.test/1.jpg',
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
          WotdPastPick(date: DateTime.utc(2026, 5, 2), wallpaper: _wall('https://a.test/new.jpg')),
          WotdPastPick(date: DateTime.utc(2026, 5), wallpaper: _wall('https://a.test/old.jpg')),
        ]),
      );

      expect(await repository.loadRemoteUrls(AutoRotateSource.wallOfTheDay), <String>[
        'https://a.test/new.jpg',
        'https://a.test/old.jpg',
      ]);
      verify(() => wotd.fetchRecent()).called(1);
    });

    test('Wall of the Day returns null on failure', () async {
      when(() => wotd.fetchRecent()).thenAnswer((_) async => Result.error(const ServerFailure('offline')));

      expect(await repository.loadRemoteUrls(AutoRotateSource.wallOfTheDay), isNull);
    });

    test('history gives unique https urls in a stable order', () async {
      final DateTime now = DateTime.utc(2026, 5);
      await history.record(_applied('1', 'https://a.test/b.jpg', now));
      await history.record(_applied('2', 'https://a.test/a.jpg', now.add(const Duration(hours: 1))));
      await history.record(_applied('3', 'https://a.test/b.jpg', now.add(const Duration(hours: 2))));
      await history.record(_applied('4', '/storage/local.jpg', now.add(const Duration(hours: 3))));

      final first = await repository.loadRemoteUrls(AutoRotateSource.history);
      await history.record(_applied('5', 'https://a.test/a.jpg', now.add(const Duration(hours: 4))));
      final second = await repository.loadRemoteUrls(AutoRotateSource.history);

      expect(first, <String>['https://a.test/a.jpg', 'https://a.test/b.jpg']);
      expect(second, first);
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
