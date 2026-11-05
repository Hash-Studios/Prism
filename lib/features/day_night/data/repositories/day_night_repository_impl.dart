import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/domain/repositories/day_night_repository.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@LazySingleton(as: DayNightRepository)
class DayNightRepositoryImpl implements DayNightRepository {
  DayNightRepositoryImpl(this._settings);

  static const String _pairKey = 'dayNight.pair';
  static const String _snapshotKey = 'shortcuts.day_night';
  static const String _group = 'daynight';
  static int _publishGeneration = 0;

  @visibleForTesting
  static Future<File?> Function(DayNightWall wall)? downloadedOriginalOverride;

  final SettingsLocalDataSource _settings;

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

  Future<Map<String, Object?>> _snapshotItem(DayNightSlot slot, DayNightWall wall, Map<String, String> paths) async {
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
