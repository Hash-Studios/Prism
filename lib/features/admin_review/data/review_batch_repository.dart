import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
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
      isStream: false,
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
      _addNotificationToBatch(
        batch,
        modifier: _safeString(payload['email']),
        title: 'Wallpaper Approved',
        body: 'Your wallpaper "${_safeString(payload['title'])}" is now live!',
        imageUrl: _safeString(payload['wallpaper_thumb']),
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
      _addNotificationToBatch(
        batch,
        modifier: _safeString(payload['email']),
        title: 'Wallpaper Rejected',
        body: reason,
        imageUrl: _safeString(payload['wallpaper_thumb']),
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
    int count = 0;

    for (final wall in walls) {
      final category = wall.data()['category']?.toString() ?? '';
      print('DEBUG: Wall ${wall.id} has category: "$category"');

      if (category.isEmpty || category == 'General') {
        print('DEBUG: Calling categorizeWallpaper for ${wall.id}');
        try {
          await functions
              .httpsCallable('categorizeWallpaper', options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
              .call(<String, dynamic>{'wallId': wall.id});
          count++;
          print('DEBUG: Successfully categorized ${wall.id}');
        } catch (e) {
          print('DEBUG: Failed to categorize ${wall.id}: $e');
        }
      }
    }
    print('DEBUG: Categorized $count wallpapers');
  }

  Future<int> getPendingWallsCount() async {
    const querySpec = FirestoreQuerySpec(
      collection: FirebaseCollections.walls,
      sourceTag: 'review_batch.pending_count',
      filters: <FirestoreFilter>[FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: false)],
      isStream: false,
    );
    final walls = await _firestoreClient.query(querySpec, (data, docId) => FirestoreDocument(docId, data));
    return walls.length;
  }

  void _addNotificationToBatch(
    FirestoreBatch batch, {
    required String modifier,
    required String title,
    required String body,
    required String imageUrl,
    String route = '',
  }) {
    if (modifier.isEmpty) return;
    batch.addDoc(FirebaseCollections.notifications, <String, dynamic>{
      'modifier': modifier,
      'notification': <String, dynamic>{'title': title, 'body': body},
      'data': <String, dynamic>{
        'pageName': '',
        'arguments': const <Object?>[],
        'url': '',
        'imageUrl': imageUrl,
        'route': route,
      },
      'createdAt': DateTime.now().toUtc(),
    });
  }

  String _safeString(Object? value) => value?.toString() ?? '';
}
