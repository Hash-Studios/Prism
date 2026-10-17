import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Writes the user's favourites as a raw JSON string, so the iOS "Get Prism Wallpaper" intent can read it
/// from UserDefaults without a running Flutter engine.
class ShortcutsFavouritesStore {
  const ShortcutsFavouritesStore._();

  static const int maxItems = 200;
  static const String nativeAssetPathsKey = 'offline.native_asset_paths';
  @visibleForTesting
  static Directory? supportDirectoryOverride;

  /// A JSON array of `{"id", "url"}`, newest first, at most [maxItems]. Walls without an id or https URL are left out.
  static String encode(Iterable<FavouriteWallEntity> items) {
    final List<FavouriteWallEntity> sorted = items.toList()..sort(compareByCreatedAtDesc);
    final Set<String> seen = <String>{};
    final List<Map<String, String>> entries = <Map<String, String>>[];
    for (final FavouriteWallEntity item in sorted) {
      final String id = item.id.trim();
      final String url = item.fullUrl.trim();
      if (id.isEmpty || !url.startsWith('https://') || !seen.add(id)) continue;
      entries.add(<String, String>{'id': id, 'url': url});
      if (entries.length == maxItems) break;
    }
    return jsonEncode(entries);
  }

  static Future<void>? _tail;
  static int _generation = 0;

  /// Writes run one after another. A save that was called before a [clear] is dropped, so it cannot land after it.
  static Future<void> save(Iterable<FavouriteWallEntity> items) {
    final int generation = _generation;
    final List<FavouriteWallEntity> selected = items.toList()..sort(compareByCreatedAtDesc);
    return _enqueue(() async {
      if (generation != _generation) return;
      final String encoded = encode(selected);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, String> relativePaths = <String, String>{};
      try {
        final Map<String, String> paths = await OfflineAssetStore.instance.localPaths();
        if (generation != _generation) return;
        if (paths.isNotEmpty) {
          final Directory supportDirectory = supportDirectoryOverride ?? await getApplicationSupportDirectory();
          final String retainedRoot = path.join(supportDirectory.path, 'prism', 'offline', 'assets');
          final Set<String> selectedIds = <String>{};
          for (final FavouriteWallEntity item in selected) {
            final String id = item.id.trim();
            final String source = item.fullUrl.trim();
            if (id.isEmpty || !selectedIds.add(id) || !source.startsWith('https://')) continue;
            final String? absolutePath = paths[source];
            if (absolutePath == null) continue;
            final String relativePath = path.relative(absolutePath, from: retainedRoot);
            if (path.isAbsolute(relativePath) ||
                relativePath == '..' ||
                relativePath.startsWith('..${path.separator}')) {
              continue;
            }
            relativePaths[source] = relativePath;
          }
        }
      } catch (_) {}
      if (generation != _generation) return;
      await NativeAssetPathsStore.replaceGroup('shortcuts', relativePaths);
      if (generation != _generation) return;
      if (!await prefs.setString(PersistenceKeys.shortcutsFavourites, encoded)) {
        throw StateError('Shortcuts favourites could not be persisted');
      }
    });
  }

  static Future<void> clear() {
    _generation++;
    return _enqueue(() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await NativeAssetPathsStore.replaceGroup('shortcuts', const <String, String>{});
      if (!await prefs.setString(PersistenceKeys.shortcutsFavourites, '[]')) {
        throw StateError('Shortcuts favourites could not be cleared');
      }
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
      await NativeAssetPathsStore.clearForUser(owner);
      if (_otherOwnerIsActive(owner) || _otherPrivateOwnerIsActive(prefs, owner)) return;
      if (!await prefs.setString(PersistenceKeys.shortcutsFavourites, '[]')) {
        throw StateError('Shortcuts favourites could not be cleared');
      }
    });
  }

  static bool _otherOwnerIsActive(String owner) {
    final String activeOwner = app_state.prismUser.loggedIn ? app_state.prismUser.id.trim() : '';
    return activeOwner.isNotEmpty && activeOwner != owner;
  }

  static bool _otherPrivateOwnerIsActive(SharedPreferences prefs, String owner) {
    final String savedOwner = prefs.getString(NativeAssetPathsStore.privateOwnerKey)?.trim() ?? '';
    return savedOwner.isNotEmpty && savedOwner != owner;
  }

  static Future<void> _enqueue(Future<void> Function() write) {
    final Future<void>? previous = _tail;
    final Future<void> result = previous == null ? write() : previous.then((_) => write());
    final Future<void> tail = result.catchError((Object _) {});
    _tail = tail;
    tail.whenComplete(() {
      if (identical(_tail, tail)) _tail = null;
    });
    return result;
  }
}
