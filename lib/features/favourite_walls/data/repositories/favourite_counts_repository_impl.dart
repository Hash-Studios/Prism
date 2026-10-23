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
  Future<Map<String, int>> fetch(Set<String> ids) async {
    final normalized = ids.map(prismStatsId).whereType<String>().toSet().toList();
    final result = <String, int>{};
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
          final raw = data['favs'];
          final count = raw is num && raw.isFinite ? raw.toInt() : int.tryParse('$raw') ?? 0;
          return MapEntry(id, math.max(0, count));
        },
      );
      result.addAll({for (final id in batch) id: 0});
      result.addEntries(rows);
    }
    return result;
  }
}
