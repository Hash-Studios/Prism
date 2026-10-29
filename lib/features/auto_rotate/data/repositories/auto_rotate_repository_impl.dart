import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart' show isWallpaperTargetSupported;
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/domain/repositories/auto_rotate_repository.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wall_of_the_day/domain/repositories/wall_of_the_day_repository.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: AutoRotateRepository)
class AutoRotateRepositoryImpl implements AutoRotateRepository {
  AutoRotateRepositoryImpl(this._settings, this._wallpapers, this._wallOfTheDay, this._history, this._folders);

  static const String _sourceKey = 'autoRotate.source';
  static const String _categoryKey = 'autoRotate.category';
  static const String _folderIdKey = 'autoRotate.folderId';
  static const String _folderNameKey = 'autoRotate.folderName';
  static const int _categoryLimit = 40;
  static const int _folderLimit = 100;
  static const String _appliedSourcesKey = 'autoRotate.appliedSources';
  static const String _passRecordKey = 'autoRotate.passRecord';
  static Future<void>? _passRecordOperation;
  static final Map<String, int> _passRecordGenerations = <String, int>{};

  final SettingsLocalDataSource _settings;
  final PrismWallpaperRepository _wallpapers;
  final WallOfTheDayRepository _wallOfTheDay;
  final WallpaperHistoryStore _history;
  final FoldersRepository _folders;

  @visibleForTesting
  static Set<aw.WallpaperRotationTrigger> triggersFor(AutoRotateConfig config) {
    final Set<aw.WallpaperRotationTrigger> triggers = <aw.WallpaperRotationTrigger>{
      if (config.chargingOnly) aw.WallpaperRotationTrigger.charging,
    };
    return triggers.isEmpty ? const <aw.WallpaperRotationTrigger>{aw.WallpaperRotationTrigger.interval} : triggers;
  }

  @override
  Future<AutoRotateConfig> loadConfig({String? ownerId}) async {
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
    final String folderId = _settings.get<String>(_folderIdKey, defaultValue: '');
    final AutoRotateSource source = AutoRotateSource.values.asNameMap()[sourceName] ?? defaults.source;
    final Map<String, Object?>? passRecord = _readPassRecord();
    final Object? storedUntilMs = passRecord?['untilMs'];
    final int passUntilMs =
        ownerId != null && ownerId.isNotEmpty && passRecord?['ownerId'] == ownerId && storedUntilMs is int
        ? storedUntilMs
        : 0;
    return AutoRotateConfig(
      enabled: _settings.get<bool>(PersistenceKeys.autoRotateEnabled, defaultValue: defaults.enabled),
      intervalMinutes: AutoRotateConfig.intervalOptions.contains(interval) ? interval : defaults.intervalMinutes,
      target: WallpaperTarget.values.asNameMap()[targetName] ?? defaults.target,
      shuffle: _settings.get<bool>(PersistenceKeys.autoRotateShuffle, defaultValue: defaults.shuffle),
      source: source == AutoRotateSource.folder && folderId.isEmpty ? defaults.source : source,
      categoryName: _settings.get<String>(_categoryKey, defaultValue: defaults.categoryName),
      chargingOnly: _settings.get<bool>(PersistenceKeys.autoRotateChargingOnly, defaultValue: defaults.chargingOnly),
      passUntil: passUntilMs > 0 ? DateTime.fromMillisecondsSinceEpoch(passUntilMs, isUtc: true) : null,
      folderId: folderId.isEmpty ? null : folderId,
      folderName: _settings.get<String>(_folderNameKey, defaultValue: defaults.folderName),
    );
  }

  @override
  Future<void> saveConfig(AutoRotateConfig config, {String? ownerId}) async {
    final int passRecordGeneration = ownerId == null ? 0 : _passRecordGenerations[ownerId] ?? 0;
    await _settings.set(PersistenceKeys.autoRotateEnabled, config.enabled);
    await _settings.set(PersistenceKeys.autoRotateIntervalMinutes, config.intervalMinutes);
    await _settings.set(PersistenceKeys.autoRotateTarget, config.target.name);
    await _settings.set(PersistenceKeys.autoRotateShuffle, config.shuffle);
    await _settings.set(_sourceKey, config.source.name);
    await _settings.set(_categoryKey, config.categoryName);
    await _settings.set(_folderIdKey, config.folderId ?? '');
    await _settings.set(_folderNameKey, config.folderName);
    await _settings.set(PersistenceKeys.autoRotateChargingOnly, config.chargingOnly);
    final DateTime? passUntil = config.passUntil;
    if (ownerId == null || ownerId.isEmpty) return;
    await _serializePassRecord(() async {
      if ((_passRecordGenerations[ownerId] ?? 0) != passRecordGeneration) return;
      if (passUntil == null) {
        final Map<String, Object?>? currentPass = _readPassRecord();
        if (currentPass?['ownerId'] == ownerId) await _settings.delete(_passRecordKey);
      } else {
        await _settings.set(
          _passRecordKey,
          jsonEncode(<String, Object?>{'ownerId': ownerId, 'untilMs': passUntil.millisecondsSinceEpoch}),
        );
      }
    });
  }

  static Future<void> clearPassRecordForUser({
    required SettingsLocalDataSource settings,
    required String ownerId,
  }) async {
    final String owner = ownerId.trim();
    if (owner.isEmpty) return;
    _passRecordGenerations[owner] = (_passRecordGenerations[owner] ?? 0) + 1;
    await _serializePassRecord(() async {
      final String? raw = settings.get<String?>(_passRecordKey);
      if (raw == null) return;
      try {
        final Map<String, Object?> record = (jsonDecode(raw) as Map<Object?, Object?>).cast<String, Object?>();
        if (record['ownerId'] == owner) await settings.delete(_passRecordKey);
      } catch (_) {}
    });
  }

  static Future<void> _serializePassRecord(Future<void> Function() operation) {
    final Future<void>? pending = _passRecordOperation;
    final Future<void> next = pending == null
        ? operation()
        : pending.then((_) => operation(), onError: (Object _, StackTrace __) => operation());
    _passRecordOperation = next;
    return next.whenComplete(() {
      if (identical(_passRecordOperation, next)) _passRecordOperation = null;
    });
  }

  Map<String, Object?>? _readPassRecord() {
    final String? raw = _settings.get<String?>(_passRecordKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map<Object?, Object?>).cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> start(AutoRotateConfig config, List<String> imageUrls) async {
    final List<String> safe = await _safeSources(imageUrls);
    if (safe.isEmpty) {
      await stop();
      return false;
    }
    final List<aw.WallpaperRotationSource> sources = safe
        .map(
          (source) => aw.WallpaperRotationSource(
            sourceType: _isLocalSource(source) ? aw.WallpaperSourceType.file : aw.WallpaperSourceType.url,
            source: _rotationSource(source),
          ),
        )
        .toList(growable: false);
    final aw.WallpaperResult result = await aw.AsyncWallpaper.startWallpaperRotation(
      aw.WallpaperRotationRequest(
        sources: sources,
        target: aw.WallpaperTarget.values.byName(config.target.name),
        intervalMinutes: config.intervalMinutes,
        order: config.shuffle ? aw.WallpaperRotationOrder.shuffle : aw.WallpaperRotationOrder.sequential,
        triggers: triggersFor(config),
      ),
    );
    if (result.isSuccess) await _settings.set(_appliedSourcesKey, jsonEncode(safe));
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
    aw.WallpaperRotationStatus status = await aw.AsyncWallpaper.getWallpaperRotationStatus();
    if (status.isRunning && await _stopUnsafeAppliedSources()) {
      status = await aw.AsyncWallpaper.getWallpaperRotationStatus();
    }
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
    if (await _stopUnsafeAppliedSources()) return false;
    final aw.WallpaperResult result = await aw.AsyncWallpaper.rotateWallpaperNow();
    return result.isSuccess;
  }

  @override
  Future<List<String>?> loadAppliedSources() async {
    final String? raw = _settings.get<String?>(_appliedSourcesKey);
    if (raw == null) return null;
    try {
      final sources = (jsonDecode(raw) as List<Object?>).cast<String>().toList(growable: false);
      if (sources.any((source) => !_isLocalSource(source) && !_isExternalSource(source))) {
        await stop();
        return null;
      }
      return sources;
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
        return _safeWallSources(
          result.data!.map((wallpaper) => (wallpaper.id, WallpaperSource.prism, wallpaper.fullUrl)),
        );
      case AutoRotateSource.wallOfTheDay:
        final result = await _wallOfTheDay.fetchRecent();
        if (result.isFailure) return null;
        return _safeWallSources(
          result.data!.map((pick) => (pick.wallpaper.id, WallpaperSource.prism, pick.wallpaper.fullUrl)),
        );
      case AutoRotateSource.history:
        // The history order changes with every wallpaper Prism sets. Sorting keeps the list the same for the same
        // wallpapers, so a new entry for a wallpaper already in the list does not restart the rotation.
        return (await _safeWallSources(
          _history.items().map(
            (item) => (item.wallpaperId ?? '', WallpaperSourceX.fromWire(item.source), item.fullUrl),
          ),
        ))..sort();
      case AutoRotateSource.favourites:
      case AutoRotateSource.downloads:
      case AutoRotateSource.folder:
        return const <String>[];
    }
  }

  @override
  Future<({bool found, List<String> urls})?> loadFolderUrls(String folderId, {required String userId}) async {
    final result = await _folders.fetchItems(folderId, userId: userId, limit: _folderLimit);
    if (result.isFailure) return null;
    final walls = result.data;
    if (walls == null) return (found: false, urls: const <String>[]);
    return (found: true, urls: await _safeWallSources(walls.map((wall) => (wall.id, wall.source, wall.fullUrl))));
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

  Future<List<String>> _safeSources(Iterable<String> sources) async {
    final Set<String> safe = <String>{};
    for (final source in sources) {
      if (_isLocalSource(source) || _isExternalSource(source)) {
        safe.add(source);
      } else if (getIt.isRegistered<DownloadedWallIndex>()) {
        final file = await getIt<DownloadedWallIndex>().localFileForLink(source);
        if (file != null) safe.add(file.path);
      }
    }
    return safe.toList(growable: false);
  }

  Future<List<String>> _safeWallSources(Iterable<(String, WallpaperSource, String)> walls) async {
    final Set<String> safe = <String>{};
    for (final (id, source, url) in walls) {
      if (_isLocalSource(url) || _isExternalSource(url)) {
        safe.add(url);
      } else if (getIt.isRegistered<DownloadedWallIndex>()) {
        final index = getIt<DownloadedWallIndex>();
        final file = id.isNotEmpty && source != WallpaperSource.unknown
            ? await index.localFileForIdentity(id: id, source: source)
            : await index.localFileForLink(url);
        if (file != null) safe.add(file.path);
      }
    }
    return safe.toList(growable: false);
  }

  bool _isExternalSource(String source) {
    final uri = Uri.tryParse(source);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        (!uri.hasPort || uri.port == 443) &&
        const <String>{'w.wallhaven.cc', 'images.pexels.com'}.contains(uri.host);
  }

  Future<bool> _stopUnsafeAppliedSources() async {
    final String? raw = _settings.get<String?>(_appliedSourcesKey);
    try {
      final sources = (jsonDecode(raw ?? 'null') as List<Object?>).cast<String>();
      if (sources.isNotEmpty && sources.every((source) => _isLocalSource(source) || _isExternalSource(source))) {
        return false;
      }
    } catch (_) {}
    await stop();
    return true;
  }

  bool _isLocalSource(String source) {
    final Uri? uri = Uri.tryParse(source);
    return uri?.scheme == 'file' || (uri?.scheme.isEmpty ?? false) && source.startsWith('/');
  }

  String _rotationSource(String source) {
    final Uri? uri = Uri.tryParse(source);
    return uri?.scheme == 'file' ? uri!.toFilePath() : source;
  }

  @override
  Future<bool> consumeBatteryTip() async {
    if (_settings.get<bool>(PersistenceKeys.autoRotateBatteryTipShown, defaultValue: false)) return false;
    await _settings.set(PersistenceKeys.autoRotateBatteryTipShown, true);
    return true;
  }
}
