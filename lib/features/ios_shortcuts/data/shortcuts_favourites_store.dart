import 'dart:convert';

import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Writes the user's favourites as a raw JSON string, so the iOS "Get Prism Wallpaper" intent can read it
/// from UserDefaults without a running Flutter engine.
class ShortcutsFavouritesStore {
  const ShortcutsFavouritesStore._();

  static const int maxItems = 200;
  static const String nativeAssetPathsKey = 'offline.native_asset_paths';

  /// A JSON array of `{"id", "url"}`, newest first, at most [maxItems]. A wall without an https URL is kept as
  /// `{"id", "asset"}` only when [originals] has its downloaded original's asset key. Walls without an id are left out.
  static String encode(Iterable<FavouriteWallEntity> items, {Set<String> originals = const <String>{}}) {
    final List<FavouriteWallEntity> sorted = items.toList()..sort(compareByCreatedAtDesc);
    final Set<String> seen = <String>{};
    final List<Map<String, String>> entries = <Map<String, String>>[];
    for (final FavouriteWallEntity item in sorted) {
      final String id = item.id.trim();
      final String url = item.fullUrl.trim();
      final String asset = NativeAssetPathsStore.originalAssetKey(item);
      if (id.isEmpty || seen.contains(id)) continue;
      if (url.startsWith('https://')) {
        entries.add(<String, String>{'id': id, 'url': url});
      } else if (originals.contains(asset)) {
        entries.add(<String, String>{'id': id, 'asset': asset});
      } else {
        continue;
      }
      seen.add(id);
      if (entries.length == maxItems) break;
    }
    return jsonEncode(entries);
  }

  static Future<void>? _tail;
  static int _generation = 0;

  /// Writes run one after another. A save that was called before a [clear] is dropped, so it cannot land after it.
  static Future<void> save(Iterable<FavouriteWallEntity> items) {
    final int generation = _generation;
    final bool loggedIn = app_state.prismUser.loggedIn;
    final String owner = loggedIn ? app_state.prismUser.id.trim() : '';
    bool current() =>
        generation == _generation &&
        app_state.prismUser.loggedIn == loggedIn &&
        (!loggedIn || app_state.prismUser.id.trim() == owner);
    final List<FavouriteWallEntity> selected = items.toList()..sort(compareByCreatedAtDesc);
    return _enqueue(() async {
      if (!current()) return;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!current()) return;
      Map<String, String> originals = <String, String>{};
      try {
        originals = await NativeAssetPathsStore.downloadedOriginalPaths(selected);
      } catch (_) {}
      if (!current()) return;
      final String encoded = encode(selected, originals: originals.keys.toSet());
      Map<String, String> relativePaths = <String, String>{};
      try {
        relativePaths = await NativeAssetPathsStore.retainedRelativePaths(
          selected.where((item) => item.id.trim().isNotEmpty).map((item) => item.fullUrl.trim()),
        );
      } catch (_) {}
      if (!current()) return;
      relativePaths.addAll(originals);
      await NativeAssetPathsStore.replaceGroup('shortcuts', relativePaths, isCurrent: current);
      if (!current()) return;
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
