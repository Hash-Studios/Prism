import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NativeAssetPathsStore {
  const NativeAssetPathsStore._();

  static const String preferenceKey = 'offline.native_asset_paths';
  static const String privateOwnerKey = '$preferenceKey.private_owner';
  static const List<String> _groups = <String>['favourites', 'shortcuts', 'folders', 'wotd', 'category'];
  static const List<String> _privateGroups = <String>['favourites', 'shortcuts', 'folders', 'wotd'];
  static Future<void> _tail = Future<void>.value();
  static int _generation = 0;
  @visibleForTesting
  static Directory? supportDirectoryOverride;

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
    Future<void> Function()? afterReplace,
  }) {
    if (!_groups.contains(group)) throw ArgumentError.value(group, 'group');
    final int generation = _generation;
    return _enqueue(() async {
      bool current() => generation == _generation && isCurrent?.call() != false;
      if (!current()) return;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!current()) return;
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
      if (_privateGroups.contains(group) && app_state.prismUser.loggedIn) {
        await prefs.setString(privateOwnerKey, app_state.prismUser.id.trim());
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
