import 'dart:math' as math;

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_counts_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: FavouriteCountsRepository)
class FavouriteCountsRepositoryImpl implements FavouriteCountsRepository {
  FavouriteCountsRepositoryImpl(this._firestore);

  final FirestoreClient _firestore;

  @override
  Future<Map<String, PrismWallpaperStats>> fetch(Set<String> ids) async {
    final normalized = ids.map(prismStatsId).whereType<String>().toSet().toList();
    final result = <String, PrismWallpaperStats>{};
    for (var start = 0; start < normalized.length; start += 30) {
      final batch = normalized.sublist(start, math.min(start + 30, normalized.length));
      final rows = await _firestore.query(
        FirestoreQuerySpec(
          collection: FirebaseCollections.wallpaperStats,
          sourceTag: 'favourite_counts.grid',
          cachePolicy: FirestoreCachePolicy.serverOnly,
          filters: [FirestoreFilter(field: firestoreDocumentIdField, op: FirestoreFilterOp.whereIn, value: batch)],
        ),
        (data, id) {
          final int? rawFavourites = switch (data['favs']) {
            final num count when count.isFinite => count.toInt(),
            final String count => int.tryParse(count),
            _ => null,
          };
          final int? rawViews = switch (data['views']) {
            final num count when count.isFinite => count.toInt(),
            final String count => int.tryParse(count),
            null => 0,
            _ => null,
          };
          return MapEntry(
            id,
            PrismWallpaperStats(
              favourites: math.max(0, rawFavourites ?? 0),
              views: rawViews != null && rawViews >= 0 ? rawViews : null,
            ),
          );
        },
      );
      result.addAll({for (final id in batch) id: const PrismWallpaperStats(favourites: 0, views: 0)});
      result.addEntries(rows);
    }
    return result;
  }
}
