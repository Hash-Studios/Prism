import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/admin_review/biz/drop_reserve.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ReviewBatchRepository {
  static const int defaultBatchSize = 20;

  final FirestoreClient _firestoreClient;

  ReviewBatchRepository(this._firestoreClient);

  /// Reads raw pages of this size until the batch holds [limit] walls outside a Drop, or the query runs out.
  static const int _pageSize = 20;

  Future<List<FirestoreDocument>> fetchPendingWallsBatch({
    int limit = defaultBatchSize,
    String? startAfterDocId,
  }) async {
    final List<FirestoreDocument> eligible = <FirestoreDocument>[];
    String? cursor = startAfterDocId;
    while (eligible.length < limit) {
      final querySpec = FirestoreQuerySpec(
        collection: FirebaseCollections.walls,
        sourceTag: 'review_batch.pending_walls',
        filters: <FirestoreFilter>[
          const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: false),
        ],
        orderBy: <FirestoreOrderBy>[const FirestoreOrderBy(field: 'createdAt', descending: true)],
        limit: _pageSize,
        startAfterDocId: cursor,
      );
      final walls = await _firestoreClient.query(querySpec, (data, docId) => FirestoreDocument(docId, data));
      eligible.addAll(walls.where((wall) => !isInDrop(wall)));
      if (walls.length < _pageSize) break;
      cursor = walls.last.id;
    }
    return eligible.take(limit).toList(growable: false);
  }

  Future<void> categorizeWalls(List<FirestoreDocument> walls) async {
    for (final wall in walls) {
      final category = wall.data()['category']?.toString() ?? '';

      if (category.isEmpty || category == 'General') {
        try {
          await appFunctions
              .httpsCallable('categorizeWallpaper', options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
              .call(<String, dynamic>{'wallId': wall.id});
        } catch (e, st) {
          logger.w('categorizeWallpaper failed', tag: 'ReviewBatch', error: e, stackTrace: st);
        }
      }
    }
  }

  Future<int> getPendingWallsCount() async {
    const querySpec = FirestoreQuerySpec(
      collection: FirebaseCollections.walls,
      sourceTag: 'review_batch.pending_count',
      filters: <FirestoreFilter>[FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: false)],
    );
    final walls = await _firestoreClient.query(querySpec, (data, docId) => FirestoreDocument(docId, data));
    return walls.where((wall) => !isInDrop(wall)).length;
  }
}
