import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';

class AdminReviewRepository {
  const AdminReviewRepository();

  Stream<List<FirestoreDocument>> watchPendingWalls() {
    return firestoreClient.watchQuery<FirestoreDocument>(
      const FirestoreQuerySpec(
        collection: FirebaseCollections.walls,
        sourceTag: 'admin_review.pending_walls',
        filters: <FirestoreFilter>[FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: false)],
        orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
        isStream: true,
      ),
      (data, docId) => FirestoreDocument(docId, data),
    );
  }

  Stream<List<FirestoreDocument>> watchPendingSetups() {
    return firestoreClient.watchQuery<FirestoreDocument>(
      const FirestoreQuerySpec(
        collection: FirebaseCollections.setups,
        sourceTag: 'admin_review.pending_setups',
        filters: <FirestoreFilter>[FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: false)],
        orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: 'created_at', descending: true)],
        isStream: true,
      ),
      (data, docId) => FirestoreDocument(docId, data),
    );
  }

  Stream<List<FirestoreDocument>> watchOpenContentReports() {
    return firestoreClient.watchQuery<FirestoreDocument>(
      const FirestoreQuerySpec(
        collection: FirebaseCollections.contentReports,
        sourceTag: 'admin_review.content_reports_open',
        filters: <FirestoreFilter>[FirestoreFilter(field: 'status', op: FirestoreFilterOp.isEqualTo, value: 'open')],
        orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
        isStream: true,
      ),
      (data, docId) => FirestoreDocument(docId, data),
    );
  }

  Future<void> markContentReportReviewed(String reportDocId, {String? resolution}) async {
    await firestoreClient.updateDoc(FirebaseCollections.contentReports, reportDocId, <String, dynamic>{
      'status': 'reviewed',
      'reviewedAt': DateTime.now().toUtc(),
      if (resolution != null && resolution.isNotEmpty) 'resolution': resolution,
    }, sourceTag: 'admin_review.mark_content_report_reviewed');
  }

  /// Returns true if the wall existed and was rejected; false if it was already missing.
  Future<bool> rejectWallByFirestoreDocumentId(String wallDocId, {required String reason}) async {
    final FirestoreDocument? wall = await firestoreClient.getById<FirestoreDocument>(
      FirebaseCollections.walls,
      wallDocId,
      (Map<String, dynamic> data, String id) => FirestoreDocument(id, data),
      sourceTag: 'admin_review.reject_wall_by_doc_id',
    );
    if (wall == null) {
      return false;
    }
    await rejectWall(wall, reason: reason);
    return true;
  }

  Future<void> approveWall(FirestoreDocument wall) async {
    final Map<String, dynamic> payload = Map<String, dynamic>.from(wall.data());
    final List<String> collections =
        (payload['collections'] as List?)
            ?.whereType<Object?>()
            .map((Object? item) => item?.toString() ?? '')
            .where((value) => value.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    await firestoreClient.runBatch((FirestoreBatch batch) async {
      batch.updateDoc(FirebaseCollections.walls, wall.id, <String, dynamic>{
        'review': true,
        'collections': collections.isEmpty ? <String>['community'] : collections,
        'reviewedAt': DateTime.now().toUtc(),
        'createdAt': DateTime.now().toUtc(),
      });
      _addUserNotificationToBatch(
        batch,
        modifier: _safeString(payload['email']),
        title: 'Wallpaper Approved',
        body: 'Your wallpaper has been approved and is now live.',
        imageUrl: _safeString(payload['wallpaper_thumb']),
        route: 'announcement',
      );
    }, sourceTag: 'admin_review.approve_wall');
  }

  Future<void> rejectWall(FirestoreDocument wall, {required String reason}) async {
    final Map<String, dynamic> payload = Map<String, dynamic>.from(wall.data());
    payload['rejectionReason'] = reason;
    payload['rejectedAt'] = DateTime.now().toUtc();

    await firestoreClient.runBatch((FirestoreBatch batch) async {
      batch.addDoc(FirebaseCollections.rejectedWalls, payload);
      batch.deleteDoc(FirebaseCollections.walls, wall.id);
      _addUserNotificationToBatch(
        batch,
        modifier: _safeString(payload['email']),
        title: 'Wallpaper Rejected',
        body: reason,
        imageUrl: _safeString(payload['wallpaper_thumb']),
        route: 'announcement',
      );
    }, sourceTag: 'admin_review.reject_wall');
  }

  Future<void> approveSetup(FirestoreDocument setup) async {
    final Map<String, dynamic> payload = Map<String, dynamic>.from(setup.data());
    await firestoreClient.runBatch((FirestoreBatch batch) async {
      batch.updateDoc(FirebaseCollections.setups, setup.id, <String, dynamic>{
        'review': true,
        'reviewedAt': DateTime.now().toUtc(),
        'created_at': DateTime.now().toUtc(),
      });
      _addUserNotificationToBatch(
        batch,
        modifier: _safeString(payload['email']),
        title: 'Setup Approved',
        body: 'Your setup has been approved and is now live.',
        imageUrl: _safeString(payload['image']),
        route: 'announcement',
      );
    }, sourceTag: 'admin_review.approve_setup');
  }

  Future<void> rejectSetup(FirestoreDocument setup, {required String reason}) async {
    final Map<String, dynamic> payload = Map<String, dynamic>.from(setup.data());
    payload['rejectionReason'] = reason;
    payload['rejectedAt'] = DateTime.now().toUtc();

    await firestoreClient.runBatch((FirestoreBatch batch) async {
      batch.addDoc(FirebaseCollections.rejectedSetups, payload);
      batch.deleteDoc(FirebaseCollections.setups, setup.id);
      _addUserNotificationToBatch(
        batch,
        modifier: _safeString(payload['email']),
        title: 'Setup Rejected',
        body: reason,
        imageUrl: _safeString(payload['image']),
        route: 'announcement',
      );
    }, sourceTag: 'admin_review.reject_setup');
  }

  void _addUserNotificationToBatch(
    FirestoreBatch batch, {
    required String modifier,
    required String title,
    required String body,
    required String imageUrl,
    String route = '',
    String wallId = '',
  }) {
    if (modifier.isEmpty) {
      return;
    }
    batch.addDoc(FirebaseCollections.notifications, <String, dynamic>{
      'modifier': modifier,
      'notification': <String, dynamic>{'title': title, 'body': body},
      'data': <String, dynamic>{
        'pageName': '',
        'arguments': const <Object?>[],
        'url': '',
        'imageUrl': imageUrl,
        'route': route,
        if (wallId.isNotEmpty) 'wall_id': wallId,
      },
      'createdAt': DateTime.now().toUtc(),
    });
  }

  String _safeString(Object? value) => value?.toString() ?? '';
}
