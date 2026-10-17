import 'dart:async';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/store_adapters/lazy_file_cache.dart';
import 'package:Prism/features/favourite_walls/domain/guest_favourites_codec.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class GuestFavouritesStore {
  GuestFavouritesStore({@ignoreParam DurableJsonStore? durableStore, @ignoreParam LazyFileCache? legacyCache})
    : _durable = durableStore ?? DurableJsonStore('guest_favourites'),
      _legacy = legacyCache ?? LazyFileCache('guest_favourites');

  static const int maxItems = 200;
  static const String _snapshotKey = '__guest::snapshot';
  static const String _legacyKey = 'guest.favourites';

  final DurableJsonStore _durable;
  final LazyFileCache _legacy;
  Future<void> _writeTail = Future<void>.value();

  Future<Map<String, Map<String, Object?>>> readAll() async {
    final snapshot = await _durable.read(_snapshotKey);
    if (snapshot != null) return GuestFavouritesCodec.decode(snapshot['itemsJson']! as String);

    final String? legacyJson = await _legacy.get(_legacyKey) as String?;
    if (legacyJson == null) return <String, Map<String, Object?>>{};
    Map<String, Map<String, Object?>> imported;
    try {
      imported = GuestFavouritesCodec.decode(legacyJson);
    } catch (_) {
      imported = <String, Map<String, Object?>>{};
    }
    await _durable.write(_snapshotKey, <String, Object?>{'itemsJson': GuestFavouritesCodec.encode(imported)});
    return imported;
  }

  /// Saves [doc] under [id] and returns how many favourites the guest has now.
  Future<int> put(String id, Map<String, dynamic> doc) => _serialize(() async {
    final Map<String, Map<String, Object?>> all = await readAll();
    all.remove(id);
    all[id] = <String, Object?>{
      for (final MapEntry<String, dynamic> entry in doc.entries)
        entry.key: entry.value is DateTime ? (entry.value! as DateTime).toUtc().toIso8601String() : entry.value,
    };
    while (all.length > maxItems) {
      all.remove(all.keys.first);
    }
    await _persist(all);
    return all.length;
  });

  Future<void> remove(Iterable<String> ids) => _serialize(() async {
    final Map<String, Map<String, Object?>> all = await readAll();
    final Set<String> drop = ids.toSet();
    all.removeWhere((String id, _) => drop.contains(id));
    await _persist(all);
  });

  Future<void> clear() => _serialize(() async {
    await _durable.delete(_snapshotKey);
    await _legacy.delete(_legacyKey);
  });

  Future<void> _persist(Map<String, Map<String, Object?>> items) =>
      _durable.write(_snapshotKey, <String, Object?>{'itemsJson': GuestFavouritesCodec.encode(items)});

  Future<T> _serialize<T>(Future<T> Function() action) {
    final Future<T> next = _writeTail.then((_) => action());
    _writeTail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
