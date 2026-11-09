import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/menu_button/set_wallpaper_choice.dart';
import 'package:Prism/features/auto_rotate/data/android_schedule_coordinator.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/domain/repositories/day_night_repository.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

@LazySingleton(as: DayNightRepository)
class DayNightRepositoryImpl implements DayNightRepository {
  DayNightRepositoryImpl(this._settings);

  static const String _pairKey = 'dayNight.pair';
  static const String _snapshotKey = 'shortcuts.day_night';
  static const String _group = 'daynight';
  static const String _lastSlotKey = 'dayNight.lastSlot';
  static int _publishGeneration = 0;

  @visibleForTesting
  static Future<File?> Function(DayNightWall wall)? downloadedOriginalOverride;

  @visibleForTesting
  static bool? runsOnDeviceOverride;

  /// Renders the readability fixes of a wall from [source] into a file. Tests replace it.
  @visibleForTesting
  static Future<File> Function(DayNightSlot slot, DayNightWall wall, String source) fixedCopyMaker = _fixedCopy;

  final SettingsLocalDataSource _settings;

  @override
  bool get runsOnDevice => runsOnDeviceOverride ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  @override
  Future<DayNightPair> load({required String ownerId}) async {
    final String owner = ownerId.trim();
    if (owner.isEmpty) return DayNightPair();
    final String raw = _settings.get<String>(_pairKey, defaultValue: '');
    if (raw.trim().isEmpty) return DayNightPair();
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return DayNightPair();
    }
    if (decoded is! Map<String, Object?> || decoded['ownerId'] != owner) return DayNightPair();
    return _pairFromJson(decoded);
  }

  @override
  Future<void> save(DayNightPair pair, {required String ownerId}) =>
      _settings.set(_pairKey, jsonEncode(_pairToJson(pair, ownerId.trim())));

  @override
  Future<void> publish(DayNightPair pair) async {
    if (runsOnDevice) return _startSchedule(pair);
    final int generation = ++_publishGeneration;
    final String owner = app_state.prismUser.id.trim();
    final bool loggedIn = app_state.prismUser.loggedIn;
    if (!loggedIn || owner.isEmpty) return;
    bool isCurrent() =>
        generation == _publishGeneration &&
        app_state.prismUser.id.trim() == owner &&
        app_state.prismUser.loggedIn == loggedIn;
    final DayNightWall? day = pair.day;
    final DayNightWall? night = pair.night;
    if (!pair.isComplete || day == null || night == null) {
      throw StateError('Day and night needs a day wall and a night wall.');
    }
    final Map<String, String> paths = <String, String>{};
    final Map<String, Object?> dayItem = await _snapshotItem(DayNightSlot.day, day, paths);
    final Map<String, Object?> nightItem = await _snapshotItem(DayNightSlot.night, night, paths);
    if (!isCurrent()) return;
    final String snapshot = jsonEncode(<String, Object?>{
      'dayStart': pair.times.dayStart.minutes,
      'nightStart': pair.times.nightStart.minutes,
      'day': dayItem,
      'night': nightItem,
    });
    await NativeAssetPathsStore.replaceGroup(
      _group,
      paths,
      isCurrent: isCurrent,
      afterReplace: () async {
        if (!isCurrent()) return;
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        if (!isCurrent()) return;
        if (!await prefs.setString(_snapshotKey, snapshot)) {
          throw StateError('Day and night snapshot could not be persisted');
        }
      },
    );
  }

  @override
  Future<void> unpublish() async {
    if (runsOnDevice) return _stopSchedule();
    final int generation = ++_publishGeneration;
    await NativeAssetPathsStore.replaceGroup(
      _group,
      const <String, String>{},
      beforeReplace: () async {
        if (generation != _publishGeneration) return;
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        if (generation != _publishGeneration) return;
        if (!await prefs.remove(_snapshotKey)) {
          throw StateError('Day and night snapshot could not be removed');
        }
      },
    );
  }

  @override
  Future<DayNightOpenResult> applyOnOpen() {
    final int generation = _publishGeneration;
    final String owner = app_state.prismUser.id.trim();
    final bool loggedIn = app_state.prismUser.loggedIn;
    return AndroidScheduleCoordinator.forSettings(_settings).run(() async {
      if (generation != _publishGeneration ||
          app_state.prismUser.id.trim() != owner ||
          app_state.prismUser.loggedIn != loggedIn) {
        return (running: true, switched: null);
      }
      final aw.DailyScheduleApplyResult result = await aw.AsyncWallpaper.applyCurrentScheduleEntry();
      final DayNightSlot? slot = switch (result.entryIndex) {
        0 => DayNightSlot.day,
        1 => DayNightSlot.night,
        _ => null,
      };
      final bool applied = result.outcome == aw.DailyScheduleApplyOutcome.applied;
      if (slot == null || !applied && result.outcome != aw.DailyScheduleApplyOutcome.alreadyCurrent) {
        return (running: false, switched: null);
      }
      if (generation != _publishGeneration ||
          app_state.prismUser.id.trim() != owner ||
          app_state.prismUser.loggedIn != loggedIn) {
        return (running: true, switched: null);
      }
      final String lastSeen = _settings.get<String>(_lastSlotKey, defaultValue: '');
      await _settings.set(PersistenceKeys.autoRotateEnabled, false);
      await _settings.set(_lastSlotKey, slot.name);
      if (applied) return (running: true, switched: (slot: slot, source: DayNightSwitchSource.appOpen));
      if (lastSeen.isEmpty || lastSeen == slot.name) return (running: true, switched: null);
      return (running: true, switched: (slot: slot, source: DayNightSwitchSource.alarm));
    });
  }

  /// Starts the Android schedule. Entry 0 is the day wall and entry 1 the night wall.
  Future<void> _startSchedule(DayNightPair pair) async {
    final int generation = ++_publishGeneration;
    final String owner = app_state.prismUser.id.trim();
    if (!app_state.prismUser.loggedIn || owner.isEmpty) return;
    final DayNightWall? day = pair.day;
    final DayNightWall? night = pair.night;
    if (!pair.isComplete || day == null || night == null) {
      throw StateError('Day and night needs a day wall and a night wall.');
    }
    final AndroidScheduleCoordinator coordinator = AndroidScheduleCoordinator.forSettings(_settings);
    final int claim = coordinator.claimDayNight();
    bool started = false;
    try {
      final aw.WallpaperRotationSource daySource = await _scheduleSource(DayNightSlot.day, day);
      final aw.WallpaperRotationSource nightSource = await _scheduleSource(DayNightSlot.night, night);
      if (generation != _publishGeneration || !app_state.prismUser.loggedIn || app_state.prismUser.id.trim() != owner) {
        return;
      }
      await coordinator.run(() async {
        if (generation != _publishGeneration ||
            !app_state.prismUser.loggedIn ||
            app_state.prismUser.id.trim() != owner) {
          return;
        }
        final aw.WallpaperResult result = await aw.AsyncWallpaper.startDailySchedule(
          aw.DailyScheduleRequest(
            entries: <aw.DailyScheduleEntry>[
              aw.DailyScheduleEntry(minuteOfDay: pair.times.dayStart.minutes, source: daySource),
              aw.DailyScheduleEntry(minuteOfDay: pair.times.nightStart.minutes, source: nightSource),
            ],
            target: aw.WallpaperTarget.values.byName(pair.target.name),
          ),
        );
        if (!result.isSuccess) throw const DayNightPrepareException(DayNightPrepareFailure.offlineCopyFailed);
        if (generation != _publishGeneration ||
            !app_state.prismUser.loggedIn ||
            app_state.prismUser.id.trim() != owner) {
          return;
        }
        await _settings.set(PersistenceKeys.autoRotateEnabled, false);
        await _settings.set(_lastSlotKey, pair.times.slotNow().name);
        started = true;
      });
    } finally {
      if (!started) coordinator.releaseDayNight(claim);
    }
  }

  Future<void> _stopSchedule() async {
    ++_publishGeneration;
    final AndroidScheduleCoordinator coordinator = AndroidScheduleCoordinator.forSettings(_settings);
    final int claim = coordinator.claim;
    await coordinator.run(() async {
      try {
        final aw.WallpaperResult result = await aw.AsyncWallpaper.stopDailySchedule();
        if (!result.isSuccess) throw StateError('Day and night could not stop the device schedule');
        await _settings.delete(_lastSlotKey);
      } finally {
        coordinator.releaseDayNight(claim);
      }
    });
  }

  /// A public wall loads from its https URL. A protected wall needs its downloaded original. A wall with readability
  /// fixes loads from a fixed copy of either.
  Future<aw.WallpaperRotationSource> _scheduleSource(DayNightSlot slot, DayNightWall wall) async {
    if (wall.fixes.isNotEmpty) {
      final File fixed = await fixedCopyMaker(slot, wall, await _fixSource(slot, wall));
      return aw.WallpaperRotationSource(sourceType: aw.WallpaperSourceType.file, source: fixed.path);
    }
    if (wall.hasPublicImage) {
      return aw.WallpaperRotationSource(sourceType: aw.WallpaperSourceType.url, source: wall.fullUrl.trim());
    }
    final File? original = await _downloadedOriginal(wall);
    if (original == null) throw DayNightPrepareException(DayNightPrepareFailure.needsDownload, slot: slot);
    return aw.WallpaperRotationSource(sourceType: aw.WallpaperSourceType.file, source: original.path);
  }

  Future<Map<String, Object?>> _snapshotItem(DayNightSlot slot, DayNightWall wall, Map<String, String> paths) async {
    if (wall.fixes.isNotEmpty) {
      final File fixed = await fixedCopyMaker(slot, wall, await _fixSource(slot, wall));
      final String? relativePath = await NativeAssetPathsStore.originalRelativePath(fixed);
      if (relativePath == null) throw DayNightPrepareException(DayNightPrepareFailure.offlineCopyFailed, slot: slot);
      final String asset = 'daynight-fixed-${slot.name}';
      paths[asset] = relativePath;
      return <String, Object?>{'id': wall.id, 'asset': asset};
    }
    final String url = wall.fullUrl.trim();
    if (wall.hasPublicImage) {
      try {
        await OfflineAssetStore.instance.retain(url);
      } catch (_) {
        throw DayNightPrepareException(DayNightPrepareFailure.offlineCopyFailed, slot: slot);
      }
      final String? relativePath = (await NativeAssetPathsStore.retainedRelativePaths(<String>[url]))[url];
      if (relativePath == null) throw DayNightPrepareException(DayNightPrepareFailure.offlineCopyFailed, slot: slot);
      paths[url] = relativePath;
      return <String, Object?>{'id': wall.id, 'url': url};
    }
    final File? original = await _downloadedOriginal(wall);
    final String? relativePath = original == null ? null : await NativeAssetPathsStore.originalRelativePath(original);
    if (relativePath == null) throw DayNightPrepareException(DayNightPrepareFailure.needsDownload, slot: slot);
    final String asset = NativeAssetPathsStore.originalAssetKeyFor(wall.source, wall.id);
    paths[asset] = relativePath;
    return <String, Object?>{'id': wall.id, 'asset': asset};
  }

  /// Where a fix renders from: the public URL, or the downloaded original of a protected wall.
  Future<String> _fixSource(DayNightSlot slot, DayNightWall wall) async {
    if (wall.hasPublicImage) return wall.fullUrl.trim();
    final File? original = await _downloadedOriginal(wall);
    if (original == null) throw DayNightPrepareException(DayNightPrepareFailure.needsDownload, slot: slot);
    return original.path;
  }

  /// A screen-size copy of the wall with its fixes, kept under the offline assets root so iOS Shortcuts can read it.
  static Future<File> _fixedCopy(DayNightSlot slot, DayNightWall wall, String source) async {
    final ui.FlutterView view =
        ui.PlatformDispatcher.instance.implicitView ?? ui.PlatformDispatcher.instance.views.first;
    final ui.Size px = view.physicalSize;
    final ui.Size portrait = ui.Size(px.shortestSide, px.longestSide);
    final PlacedWallpaper placed = await PlacedWallpaper.render(
      source,
      WallpaperPlacement(fixes: wall.fixes),
      portrait,
    );
    try {
      final Directory support = await getApplicationSupportDirectory();
      final Directory folder = Directory(path.join(support.path, 'prism', 'offline', 'assets', 'day_night_fixed'));
      await folder.create(recursive: true);
      final Directory destination = await Directory(folder.path).createTemp('${slot.name}-');
      return await File(placed.path).copy(path.join(destination.path, 'wall.png'));
    } finally {
      await placed.discard();
    }
  }

  Future<File?> _downloadedOriginal(DayNightWall wall) {
    final Future<File?> Function(DayNightWall wall)? override = downloadedOriginalOverride;
    if (override != null) return override(wall);
    if (!getIt.isRegistered<DownloadedWallIndex>()) return Future<File?>.value();
    return getIt<DownloadedWallIndex>().localFileForIdentity(id: wall.id, source: wall.source);
  }

  static Map<String, Object?> _pairToJson(DayNightPair pair, String owner) => <String, Object?>{
    'ownerId': owner,
    if (pair.day case final DayNightWall day) 'day': day.toJson(),
    if (pair.night case final DayNightWall night) 'night': night.toJson(),
    'dayStart': pair.times.dayStart.minutes,
    'nightStart': pair.times.nightStart.minutes,
    'target': pair.target.name,
    'enabled': pair.enabled,
    'fromVariants': pair.fromVariants,
    if (pair.passUntil case final DateTime until) 'passUntilMs': until.millisecondsSinceEpoch,
  };

  static DayNightPair _pairFromJson(Map<String, Object?> json) {
    final DayTime? dayStart = DayTime.fromMinutes(json['dayStart']);
    final DayTime? nightStart = DayTime.fromMinutes(json['nightStart']);
    final DayNightTimes? times = dayStart == null || nightStart == null
        ? null
        : DayNightTimes.tryCreate(dayStart, nightStart);
    return DayNightPair(
      day: DayNightWall.fromJson(json['day']),
      night: DayNightWall.fromJson(json['night']),
      times: times ?? DayNightTimes.standard,
      target: WallpaperTarget.values.asNameMap()[json['target']] ?? WallpaperTarget.both,
      enabled: json['enabled'] == true,
      fromVariants: json['fromVariants'] == true,
      passUntil: switch (json['passUntilMs']) {
        final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        _ => null,
      },
    );
  }
}
