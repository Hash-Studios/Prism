import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ReviewBatchRepository {
  static const int defaultBatchSize = 20;

  final FirestoreClient _firestoreClient;

  ReviewBatchRepository(this._firestoreClient);

  Future<List<FirestoreDocument>> fetchPendingWallsBatch({
    int limit = defaultBatchSize,
    String? startAfterDocId,
  }) async {
    final querySpec = FirestoreQuerySpec(
      collection: FirebaseCollections.walls,
      sourceTag: 'review_batch.pending_walls',
      filters: <FirestoreFilter>[const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: false)],
      orderBy: <FirestoreOrderBy>[const FirestoreOrderBy(field: 'createdAt', descending: true)],
      limit: limit,
      startAfterDocId: startAfterDocId,
    );

    final walls = await _firestoreClient.query(querySpec, (data, docId) => FirestoreDocument(docId, data));
    return walls;
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
    return walls.length;
  }
}
