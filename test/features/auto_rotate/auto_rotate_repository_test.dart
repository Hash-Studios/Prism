import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/auto_rotate/data/repositories/auto_rotate_repository_impl.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:async_wallpaper/pigeon_impl_api.dart' as api;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/in_memory_local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const String stopChannel = 'dev.flutter.pigeon.async_wallpaper.WallpaperApi.stopWallpaperRotation';
  const String statusChannel = 'dev.flutter.pigeon.async_wallpaper.WallpaperApi.getWallpaperRotationStatus';
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late AutoRotateRepositoryImpl repository;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    repository = AutoRotateRepositoryImpl(SettingsLocalDataSource(InMemoryLocalStore()));
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
      activeHoursEnabled: true,
      activeHoursStart: 22,
      activeHoursEnd: 7,
    );

    await repository.saveConfig(config);

    expect(await repository.loadConfig(), config);
  });

  test('ignores stored hours outside 0 to 23', () async {
    final InMemoryLocalStore store = InMemoryLocalStore();
    final AutoRotateRepositoryImpl repo = AutoRotateRepositoryImpl(SettingsLocalDataSource(store));
    await repo.saveConfig(const AutoRotateConfig(activeHoursStart: 40, activeHoursEnd: -2));

    final AutoRotateConfig loaded = await repo.loadConfig();

    expect(loaded.activeHoursStart, 6);
    expect(loaded.activeHoursEnd, 23);
  });

  test('maps the options to plugin triggers', () {
    expect(AutoRotateRepositoryImpl.triggersFor(const AutoRotateConfig()), <aw.WallpaperRotationTrigger>{
      aw.WallpaperRotationTrigger.interval,
    });
    expect(
      AutoRotateRepositoryImpl.triggersFor(const AutoRotateConfig(chargingOnly: true)),
      <aw.WallpaperRotationTrigger>{aw.WallpaperRotationTrigger.charging},
    );
    expect(
      AutoRotateRepositoryImpl.triggersFor(const AutoRotateConfig(activeHoursEnabled: true)),
      <aw.WallpaperRotationTrigger>{aw.WallpaperRotationTrigger.timeOfDay},
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
}
