import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_store.dart';
import 'package:injectable/injectable.dart';

const int _maxBatchWrites = 400;
const Duration _networkTimeout = Duration(seconds: 15);

/// Moves the favourites a guest saved on this device into the account they just signed in to.
@lazySingleton
class GuestFavouritesMerger {
  GuestFavouritesMerger(this._firestoreClient, this._store, this._favoritesLocal);

  final FirestoreClient _firestoreClient;
  final GuestFavouritesStore _store;
  final FavoritesLocalDataSource _favoritesLocal;

  /// Adds every guest favourite the account does not have yet, then clears the guest list.
  /// A wall that is already in the account keeps its server doc. Throws when the network
  /// step fails, and the guest list stays on the device for the next try. Returns how many were added.
  Future<int> mergeInto(String userId) async {
    final Map<String, Map<String, Object?>> saved = await _store.readAll();
    if (saved.isEmpty) return 0;
    final String path = 'usersv2/$userId/images';
    final Set<String> existing =
        (await _firestoreClient
                .query<String>(
                  FirestoreQuerySpec(collection: path, sourceTag: 'favourite_walls.guest_merge.existing'),
                  (data, docId) => docId,
                )
                .timeout(_networkTimeout))
            .toSet();
    final List<MapEntry<String, Map<String, Object?>>> missing = saved.entries
        .where((entry) => !existing.contains(entry.key))
        .toList(growable: false);
    for (int start = 0; start < missing.length; start += _maxBatchWrites) {
      final List<MapEntry<String, Map<String, Object?>>> chunk = missing.sublist(
        start,
        math.min(start + _maxBatchWrites, missing.length),
      );
      await _firestoreClient
          .runBatch((batch) async {
            for (final MapEntry<String, Map<String, Object?>> entry in chunk) {
              batch.setDoc(path, entry.key, _withDates(entry.value));
            }
          }, sourceTag: 'favourite_walls.guest_merge')
          .timeout(_networkTimeout);
    }
    await _store.clear();
    await _favoritesLocal.replaceWallFavourites('', const <String>[]);
    if (missing.isNotEmpty) unawaited(analytics.track(GuestFavouritesMergedEvent(count: missing.length)));
    return missing.length;
  }

  Map<String, dynamic> _withDates(Map<String, Object?> doc) {
    return <String, dynamic>{
      for (final MapEntry<String, Object?> entry in doc.entries)
        entry.key: (entry.key == 'createdAt' || entry.key == 'favouritedAt') && entry.value is String
            ? DateTime.tryParse(entry.value! as String) ?? entry.value
            : entry.value,
    };
  }
}
