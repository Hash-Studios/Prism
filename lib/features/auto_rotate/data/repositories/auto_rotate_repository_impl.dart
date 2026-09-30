import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/domain/repositories/auto_rotate_repository.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:injectable/injectable.dart';

@LazySingleton(as: AutoRotateRepository)
class AutoRotateRepositoryImpl implements AutoRotateRepository {
  AutoRotateRepositoryImpl(this._settings);

  final SettingsLocalDataSource _settings;

  @override
  Future<AutoRotateConfig> loadConfig() async {
    const AutoRotateConfig defaults = AutoRotateConfig();
    final int interval = _settings.get<int>(
      PersistenceKeys.autoRotateIntervalMinutes,
      defaultValue: defaults.intervalMinutes,
    );
    final String targetName = _settings.get<String>(
      PersistenceKeys.autoRotateTarget,
      defaultValue: defaults.target.name,
    );
    return AutoRotateConfig(
      enabled: _settings.get<bool>(PersistenceKeys.autoRotateEnabled, defaultValue: defaults.enabled),
      intervalMinutes: AutoRotateConfig.intervalOptions.contains(interval) ? interval : defaults.intervalMinutes,
      target: WallpaperTarget.values.asNameMap()[targetName] ?? defaults.target,
      shuffle: _settings.get<bool>(PersistenceKeys.autoRotateShuffle, defaultValue: defaults.shuffle),
    );
  }

  @override
  Future<void> saveConfig(AutoRotateConfig config) async {
    await _settings.set(PersistenceKeys.autoRotateEnabled, config.enabled);
    await _settings.set(PersistenceKeys.autoRotateIntervalMinutes, config.intervalMinutes);
    await _settings.set(PersistenceKeys.autoRotateTarget, config.target.name);
    await _settings.set(PersistenceKeys.autoRotateShuffle, config.shuffle);
  }

  @override
  Future<bool> start(AutoRotateConfig config, List<String> imageUrls) async {
    final aw.WallpaperResult result = await aw.AsyncWallpaper.startWallpaperRotation(
      aw.WallpaperRotationRequest(
        sources: imageUrls
            .map((url) => aw.WallpaperRotationSource(sourceType: aw.WallpaperSourceType.url, source: url))
            .toList(growable: false),
        target: aw.WallpaperTarget.values.byName(config.target.name),
        intervalMinutes: config.intervalMinutes,
        order: config.shuffle ? aw.WallpaperRotationOrder.shuffle : aw.WallpaperRotationOrder.sequential,
      ),
    );
    return result.isSuccess;
  }

  @override
  Future<void> stop() async {
    await aw.AsyncWallpaper.stopWallpaperRotation();
  }

  @override
  Future<AutoRotateStatus> status() async {
    final aw.WallpaperRotationStatus status = await aw.AsyncWallpaper.getWallpaperRotationStatus();
    return AutoRotateStatus(isRunning: status.isRunning, nextRunEpochMs: status.nextRunEpochMs);
  }

  @override
  Future<bool> rotateNow() async {
    final aw.WallpaperResult result = await aw.AsyncWallpaper.rotateWallpaperNow();
    return result.isSuccess;
  }
}
