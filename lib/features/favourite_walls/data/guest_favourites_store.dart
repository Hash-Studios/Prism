import 'dart:convert';

import 'package:Prism/core/persistence/store_adapters/lazy_file_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Favourites saved while signed out. They live in one file on the device until the user signs in,
/// then [GuestFavouritesMerger] moves them into the account.
///
/// Each value is the same doc map that a signed-in favourite writes to Firestore, with dates as ISO strings.
@lazySingleton
class GuestFavouritesStore {
  GuestFavouritesStore() : _cache = LazyFileCache('guest_favourites');

  @visibleForTesting
  GuestFavouritesStore.withCache(this._cache);

  /// A guest who saves more than this loses the oldest favourite.
  static const int maxItems = 200;

  static const String _key = 'guest.favourites';

  final LazyFileCache _cache;

  /// Doc maps by wall id, oldest first. A damaged file reads as empty.
  Future<Map<String, Map<String, Object?>>> readAll() async {
    final stored = await _cache.get(_key);
    if (stored == null) return <String, Map<String, Object?>>{};
    try {
      final decoded = jsonDecode(stored as String) as Map<String, dynamic>;
      return <String, Map<String, Object?>>{
        for (final MapEntry<String, dynamic> entry in decoded.entries)
          entry.key: Map<String, Object?>.of(entry.value as Map<String, dynamic>),
      };
    } catch (_) {
      return <String, Map<String, Object?>>{};
    }
  }

  /// Saves [doc] under [id] and returns how many favourites the guest has now.
  Future<int> put(String id, Map<String, dynamic> doc) async {
    final Map<String, Map<String, Object?>> all = await readAll();
    all.remove(id);
    all[id] = <String, Object?>{
      for (final MapEntry<String, dynamic> entry in doc.entries)
        entry.key: entry.value is DateTime ? (entry.value as DateTime).toUtc().toIso8601String() : entry.value,
    };
    while (all.length > maxItems) {
      all.remove(all.keys.first);
    }
    await _cache.set(_key, jsonEncode(all));
    return all.length;
  }

  Future<void> remove(Iterable<String> ids) async {
    final Map<String, Map<String, Object?>> all = await readAll();
    final Set<String> drop = ids.toSet();
    all.removeWhere((String id, _) => drop.contains(id));
    await _cache.set(_key, jsonEncode(all));
  }

  Future<void> clear() => _cache.delete(_key);
}
