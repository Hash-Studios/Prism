import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart' show isWallpaperTargetSupported;
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/domain/repositories/auto_rotate_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wall_of_the_day/domain/repositories/wall_of_the_day_repository.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: AutoRotateRepository)
class AutoRotateRepositoryImpl implements AutoRotateRepository {
  AutoRotateRepositoryImpl(this._settings, this._wallpapers, this._wallOfTheDay, this._history);

  static const String _sourceKey = 'autoRotate.source';
  static const String _categoryKey = 'autoRotate.category';
  static const int _categoryLimit = 40;
  static const String _appliedSourcesKey = 'autoRotate.appliedSources';

  final SettingsLocalDataSource _settings;
  final PrismWallpaperRepository _wallpapers;
  final WallOfTheDayRepository _wallOfTheDay;
  final WallpaperHistoryStore _history;

  @visibleForTesting
  static Set<aw.WallpaperRotationTrigger> triggersFor(AutoRotateConfig config) {
    final Set<aw.WallpaperRotationTrigger> triggers = <aw.WallpaperRotationTrigger>{
      if (config.chargingOnly) aw.WallpaperRotationTrigger.charging,
    };
    return triggers.isEmpty ? const <aw.WallpaperRotationTrigger>{aw.WallpaperRotationTrigger.interval} : triggers;
  }

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
    final String sourceName = _settings.get<String>(_sourceKey, defaultValue: defaults.source.name);
    return AutoRotateConfig(
      enabled: _settings.get<bool>(PersistenceKeys.autoRotateEnabled, defaultValue: defaults.enabled),
      intervalMinutes: AutoRotateConfig.intervalOptions.contains(interval) ? interval : defaults.intervalMinutes,
      target: WallpaperTarget.values.asNameMap()[targetName] ?? defaults.target,
      shuffle: _settings.get<bool>(PersistenceKeys.autoRotateShuffle, defaultValue: defaults.shuffle),
      source: AutoRotateSource.values.asNameMap()[sourceName] ?? defaults.source,
      categoryName: _settings.get<String>(_categoryKey, defaultValue: defaults.categoryName),
      chargingOnly: _settings.get<bool>(PersistenceKeys.autoRotateChargingOnly, defaultValue: defaults.chargingOnly),
    );
  }

  @override
  Future<void> saveConfig(AutoRotateConfig config) async {
    await _settings.set(PersistenceKeys.autoRotateEnabled, config.enabled);
    await _settings.set(PersistenceKeys.autoRotateIntervalMinutes, config.intervalMinutes);
    await _settings.set(PersistenceKeys.autoRotateTarget, config.target.name);
    await _settings.set(PersistenceKeys.autoRotateShuffle, config.shuffle);
    await _settings.set(_sourceKey, config.source.name);
    await _settings.set(_categoryKey, config.categoryName);
    await _settings.set(PersistenceKeys.autoRotateChargingOnly, config.chargingOnly);
  }

  @override
  Future<bool> start(AutoRotateConfig config, List<String> imageUrls) async {
    final aw.WallpaperSourceType sourceType = config.source == AutoRotateSource.downloads
        ? aw.WallpaperSourceType.file
        : aw.WallpaperSourceType.url;
    final aw.WallpaperResult result = await aw.AsyncWallpaper.startWallpaperRotation(
      aw.WallpaperRotationRequest(
        sources: imageUrls
            .map((url) => aw.WallpaperRotationSource(sourceType: sourceType, source: url))
            .toList(growable: false),
        target: aw.WallpaperTarget.values.byName(config.target.name),
        intervalMinutes: config.intervalMinutes,
        order: config.shuffle ? aw.WallpaperRotationOrder.shuffle : aw.WallpaperRotationOrder.sequential,
        triggers: triggersFor(config),
      ),
    );
    if (result.isSuccess) await _settings.set(_appliedSourcesKey, jsonEncode(imageUrls));
    return result.isSuccess;
  }

  @override
  Future<bool> stop() async {
    final aw.WallpaperResult result = await aw.AsyncWallpaper.stopWallpaperRotation();
    if (result.isSuccess) await _settings.delete(_appliedSourcesKey);
    return result.isSuccess;
  }

  @override
  Future<AutoRotateStatus> status() async {
    final aw.WallpaperRotationStatus status = await aw.AsyncWallpaper.getWallpaperRotationStatus();
    return AutoRotateStatus(
      isRunning: status.isRunning,
      nextRunEpochMs: status.nextRunEpochMs,
      lastError: status.lastError,
      cachedCount: status.cachedCount,
      totalCount: status.totalCount,
    );
  }

  @override
  Future<bool> rotateNow() async {
    final aw.WallpaperResult result = await aw.AsyncWallpaper.rotateWallpaperNow();
    return result.isSuccess;
  }

  @override
  Future<List<String>?> loadAppliedSources() async {
    final String? raw = _settings.get<String?>(_appliedSourcesKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List<Object?>).cast<String>().toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<String>> listDownloads() async {
    try {
      final DownloadItemsResult result = await PrismMediaHostApi().listDownloads();
      if (!result.success) return const <String>[];
      return result.items.where((path) => File(path).existsSync()).toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  @override
  Future<List<String>?> loadRemoteUrls(AutoRotateSource source, {String? category}) async {
    switch (source) {
      case AutoRotateSource.category:
        final result = await _wallpapers.fetchByCategory(
          category ?? const AutoRotateConfig().categoryName,
          limit: _categoryLimit,
          sourceTag: 'auto_rotate.category',
        );
        if (result.isFailure) return null;
        return _uniqueHttps(result.data!.map((wallpaper) => wallpaper.fullUrl));
      case AutoRotateSource.wallOfTheDay:
        final result = await _wallOfTheDay.fetchRecent();
        if (result.isFailure) return null;
        return _uniqueHttps(result.data!.map((pick) => pick.wallpaper.fullUrl));
      case AutoRotateSource.history:
        // The history order changes with every wallpaper Prism sets. Sorting keeps the list the same for the same
        // wallpapers, so a new entry for a wallpaper already in the list does not restart the rotation.
        return _uniqueHttps(_history.items().map((item) => item.fullUrl)).toList()..sort();
      case AutoRotateSource.favourites:
      case AutoRotateSource.downloads:
        return const <String>[];
    }
  }

  @override
  Future<Set<WallpaperTarget>> supportedTargets() async {
    try {
      final aw.WallpaperCapabilities capabilities = await aw.AsyncWallpaper.getCapabilities();
      return WallpaperTarget.values.where((target) => isWallpaperTargetSupported(capabilities, target)).toSet();
    } catch (_) {
      return WallpaperTarget.values.toSet();
    }
  }

  List<String> _uniqueHttps(Iterable<String> urls) {
    final Set<String> seen = <String>{};
    return urls
        .where((url) => Uri.tryParse(url)?.scheme.toLowerCase() == 'https')
        .where(seen.add)
        .toList(growable: false);
  }

  @override
  Future<bool> consumeBatteryTip() async {
    if (_settings.get<bool>(PersistenceKeys.autoRotateBatteryTipShown, defaultValue: false)) return false;
    await _settings.set(PersistenceKeys.autoRotateBatteryTipShown, true);
    return true;
  }
}
