import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NativeAssetPathsStore {
  const NativeAssetPathsStore._();

  static const String preferenceKey = 'offline.native_asset_paths';
  static const String privateOwnerKey = '$preferenceKey.private_owner';
  static const List<String> _groups = <String>['favourites', 'shortcuts', 'folders', 'wotd', 'category', 'daynight'];
  static const List<String> _privateGroups = <String>['favourites', 'shortcuts', 'folders', 'wotd', 'daynight'];
  static Future<void> _tail = Future<void>.value();
  static int _generation = 0;
  @visibleForTesting
  static Directory? supportDirectoryOverride;
  @visibleForTesting
  static Directory? documentsDirectoryOverride;
  @visibleForTesting
  static Future<File?> Function(FavouriteWallEntity wall)? downloadedOriginalOverride;

  /// The key the Shortcuts intent reads a wall's downloaded original by. A protected wall has no public URL.
  static String originalAssetKey(FavouriteWallEntity wall) => originalAssetKeyFor(wall.source, wall.id);

  static String originalAssetKeyFor(WallpaperSource source, String id) =>
      'original:${source.legacyProviderString.toLowerCase()}_$id';

  /// The path of [original] under the retained root or the downloads root, or null when it is under neither.
  static Future<String?> originalRelativePath(File original) async {
    final Directory supportDirectory = supportDirectoryOverride ?? await getApplicationSupportDirectory();
    final Directory documentsDirectory = documentsDirectoryOverride ?? await getApplicationDocumentsDirectory();
    return _relativeOriginalPath(
      original,
      path.join(supportDirectory.path, 'prism', 'offline', 'assets'),
      path.join(documentsDirectory.path, 'PrismDownloads'),
    );
  }

  static String? _relativeOriginalPath(File original, String retainedRoot, String downloadsRoot) {
    final String root = path.isWithin(retainedRoot, original.path) ? retainedRoot : downloadsRoot;
    final String relativePath = path.relative(original.path, from: root);
    if (path.isAbsolute(relativePath) || relativePath == '..' || relativePath.startsWith('..${path.separator}')) {
      return null;
    }
    return relativePath;
  }

  /// The downloaded original of each wall in [walls] that has no https URL, keyed by [originalAssetKey], as a path
  /// under the retained or downloads root. Only originals the user already got are used, so no coin gate is skipped.
  static Future<Map<String, String>> downloadedOriginalPaths(Iterable<FavouriteWallEntity> walls) async {
    final String owner = app_state.prismUser.id.trim();
    final bool loggedIn = app_state.prismUser.loggedIn;
    bool ownerIsCurrent() => app_state.prismUser.loggedIn == loggedIn && app_state.prismUser.id.trim() == owner;
    final List<FavouriteWallEntity> protected = walls
        .where((wall) => wall.id.trim().isNotEmpty && !wall.fullUrl.trim().startsWith('https://'))
        .toList();
    final Map<String, String> relativePaths = <String, String>{};
    if (protected.isEmpty) return relativePaths;
    final Future<File?> Function(FavouriteWallEntity wall)? lookup =
        downloadedOriginalOverride ??
        (getIt.isRegistered<DownloadedWallIndex>()
            ? (wall) => getIt<DownloadedWallIndex>().localFileForIdentity(id: wall.id, source: wall.source)
            : null);
    if (lookup == null) return relativePaths;
    final Directory supportDirectory = supportDirectoryOverride ?? await getApplicationSupportDirectory();
    if (!ownerIsCurrent()) return <String, String>{};
    final Directory documentsDirectory = documentsDirectoryOverride ?? await getApplicationDocumentsDirectory();
    if (!ownerIsCurrent()) return <String, String>{};
    final String retainedRoot = path.join(supportDirectory.path, 'prism', 'offline', 'assets');
    final String downloadsRoot = path.join(documentsDirectory.path, 'PrismDownloads');
    for (final FavouriteWallEntity wall in protected) {
      final File? original = await lookup(wall);
      if (!ownerIsCurrent()) return <String, String>{};
      if (original == null) continue;
      final String? relativePath = _relativeOriginalPath(original, retainedRoot, downloadsRoot);
      if (relativePath == null) continue;
      relativePaths[originalAssetKey(wall)] = relativePath;
    }
    return ownerIsCurrent() ? relativePaths : <String, String>{};
  }

  /// Each https source in [sources] with a retained offline copy, mapped to its path under the retained root.
  static Future<Map<String, String>> retainedRelativePaths(Iterable<String> sources) async {
    final Map<String, String> relativePaths = <String, String>{};
    final Map<String, String> paths = await OfflineAssetStore.instance.localPaths();
    if (paths.isEmpty) return relativePaths;
    final Directory supportDirectory = supportDirectoryOverride ?? await getApplicationSupportDirectory();
    final String retainedRoot = path.join(supportDirectory.path, 'prism', 'offline', 'assets');
    for (final String source in sources) {
      if (!source.startsWith('https://')) continue;
      final String? absolutePath = paths[source];
      if (absolutePath == null) continue;
      final String relativePath = path.relative(absolutePath, from: retainedRoot);
      if (path.isAbsolute(relativePath) || relativePath == '..' || relativePath.startsWith('..${path.separator}')) {
        continue;
      }
      relativePaths[source] = relativePath;
    }
    return relativePaths;
  }

  static Future<void> replaceGroup(
    String group,
    Map<String, String> paths, {
    bool Function()? isCurrent,
    Future<void> Function()? beforeReplace,
    Future<void> Function()? afterReplace,
  }) {
    if (!_groups.contains(group)) throw ArgumentError.value(group, 'group');
    final int generation = _generation;
    final String owner = app_state.prismUser.id.trim();
    final bool loggedIn = app_state.prismUser.loggedIn;
    final bool privateGroup = _privateGroups.contains(group);
    final bool privateOwnerWrite = loggedIn && owner.isNotEmpty && privateGroup;
    return _enqueue(() async {
      bool current() =>
          generation == _generation &&
          (!privateGroup || (app_state.prismUser.loggedIn == loggedIn && app_state.prismUser.id.trim() == owner)) &&
          isCurrent?.call() != false;
      if (!current()) return;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!current()) return;
      await beforeReplace?.call();
      if (!current()) return;
      if (privateOwnerWrite && (prefs.getString(privateOwnerKey)?.trim() ?? '') != owner) {
        for (final String privateGroup in _privateGroups) {
          if (!current()) return;
          if (!await prefs.setString('$preferenceKey.$privateGroup', '{}')) {
            throw StateError('Private native retained asset paths could not be replaced');
          }
        }
        if (!current()) return;
        if (!await prefs.remove(QuickTileConfigService.wotdRetainedKey)) {
          throw StateError('Private native retained asset paths could not be replaced');
        }
      }
      final Map<String, String> combined = <String, String>{};
      for (final String name in _groups) {
        final String raw = name == group ? jsonEncode(paths) : prefs.getString('$preferenceKey.$name') ?? '{}';
        try {
          final Object? decoded = jsonDecode(raw);
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              if (entry.key is String && entry.value is String) combined[entry.key as String] = entry.value as String;
            }
          }
        } on FormatException {
          continue;
        }
      }
      if (!current()) return;
      if (!await prefs.setString('$preferenceKey.$group', jsonEncode(paths))) {
        throw StateError('Native retained asset paths could not be persisted');
      }
      if (!current()) return;
      if (!await prefs.setString(preferenceKey, jsonEncode(combined))) {
        throw StateError('Native retained asset paths could not be persisted');
      }
      if (!current()) return;
      if (privateOwnerWrite) {
        if (!await prefs.setString(privateOwnerKey, owner)) {
          throw StateError('Private native retained asset paths could not be replaced');
        }
      }
      if (current()) await afterReplace?.call();
    });
  }

  static Future<void> clearForUser(String userId) async {
    final String owner = userId.trim();
    if (owner.isEmpty || _otherOwnerIsActive(owner)) return;
    _generation++;
    await _enqueue(() async {
      if (_otherOwnerIsActive(owner)) return;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (_otherOwnerIsActive(owner) || _otherPrivateOwnerIsActive(prefs, owner)) return;
      for (final String group in _privateGroups) {
        if (!await prefs.setString('$preferenceKey.$group', '{}')) {
          throw StateError('Private native retained asset paths could not be cleared');
        }
      }
      if (!await prefs.remove(QuickTileConfigService.wotdRetainedKey)) {
        throw StateError('Private native retained asset paths could not be cleared');
      }
      if (_otherOwnerIsActive(owner) || _otherPrivateOwnerIsActive(prefs, owner)) return;
      final Map<String, String> combined = <String, String>{};
      for (final String group in const <String>['category']) {
        try {
          final Object? decoded = jsonDecode(prefs.getString('$preferenceKey.$group') ?? '{}');
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              if (entry.key is String && entry.value is String) combined[entry.key as String] = entry.value as String;
            }
          }
        } on FormatException {
          continue;
        }
      }
      if (_otherOwnerIsActive(owner) || _otherPrivateOwnerIsActive(prefs, owner)) return;
      if (!await prefs.setString(preferenceKey, jsonEncode(combined))) {
        throw StateError('Private native retained asset paths could not be cleared');
      }
    });
  }

  static bool _otherOwnerIsActive(String owner) {
    final String activeOwner = app_state.prismUser.loggedIn ? app_state.prismUser.id.trim() : '';
    return activeOwner.isNotEmpty && activeOwner != owner;
  }

  static bool _otherPrivateOwnerIsActive(SharedPreferences prefs, String owner) {
    final String savedOwner = prefs.getString(privateOwnerKey)?.trim() ?? '';
    return savedOwner.isNotEmpty && savedOwner != owner;
  }

  static Future<void> _enqueue(Future<void> Function() operation) {
    final Future<void> result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
