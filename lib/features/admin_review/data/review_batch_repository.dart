import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/admin_review/data/wall_moderation_ops.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ReviewBatchRepository {
  static const int defaultBatchSize = 20;
  static const int maxUndoStack = 5;

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

  Future<void> approveWall(FirestoreDocument wall, {List<String>? collections}) async {
    final payload = Map<String, dynamic>.from(wall.data());
    final wallCollections =
        collections ??
        (payload['collections'] as List?)
            ?.whereType<Object?>()
            .map((Object? item) => item?.toString() ?? '')
            .where((value) => value.isNotEmpty)
            .toList(growable: false) ??
        <String>[];

    await _firestoreClient.runBatch((FirestoreBatch batch) async {
      batch.updateDoc(FirebaseCollections.walls, wall.id, <String, dynamic>{
        'review': true,
        'collections': wallCollections.isEmpty ? <String>['community'] : wallCollections,
        'reviewedAt': DateTime.now().toUtc(),
        'createdAt': DateTime.now().toUtc(),
      });
      addModerationNotificationToBatch(
        batch,
        modifier: safeModerationString(payload['email']),
        title: 'Wallpaper Approved',
        body: 'Your wallpaper "${safeModerationString(payload['title'])}" is now live!',
        imageUrl: safeModerationString(payload['wallpaper_thumb']),
        route: 'announcement',
      );
    }, sourceTag: 'review_batch.approve_wall');
  }

  Future<void> rejectWall(FirestoreDocument wall, {required String reason}) async {
    final payload = Map<String, dynamic>.from(wall.data());
    payload['rejectionReason'] = reason;
    payload['rejectedAt'] = DateTime.now().toUtc();

    await _firestoreClient.runBatch((FirestoreBatch batch) async {
      batch.addDoc(FirebaseCollections.rejectedWalls, payload);
      batch.deleteDoc(FirebaseCollections.walls, wall.id);
      addModerationNotificationToBatch(
        batch,
        modifier: safeModerationString(payload['email']),
        title: 'Wallpaper Rejected',
        body: reason,
        imageUrl: safeModerationString(payload['wallpaper_thumb']),
        route: 'announcement',
      );
    }, sourceTag: 'review_batch.reject_wall');
  }

  Future<void> updateWallCategory(String wallId, String category) async {
    await _firestoreClient.updateDoc(FirebaseCollections.walls, wallId, <String, dynamic>{
      'category': category,
    }, sourceTag: 'review_batch.update_category');
  }

  Future<void> categorizeWalls(List<FirestoreDocument> walls) async {
    final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

    for (final wall in walls) {
      final category = wall.data()['category']?.toString() ?? '';

      if (category.isEmpty || category == 'General') {
        try {
          await functions
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
