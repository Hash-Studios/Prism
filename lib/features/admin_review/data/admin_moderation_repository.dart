import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AdminModerationRepository {
  AdminModerationRepository(this._client);

  final FirestoreClient _client;

  static FirestoreDocument _toDocument(Map<String, dynamic> data, String id) => FirestoreDocument(id, data);

  Stream<List<FirestoreDocument>> watchPendingWalls() {
    return _client.watchQuery<FirestoreDocument>(
      const FirestoreQuerySpec(
        collection: FirebaseCollections.walls,
        sourceTag: 'admin_review.pending_walls',
        filters: <FirestoreFilter>[FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: false)],
        orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
        isStream: true,
      ),
      _toDocument,
    );
  }

  Stream<List<FirestoreDocument>> watchOpenContentReports() {
    return _client.watchQuery<FirestoreDocument>(
      const FirestoreQuerySpec(
        collection: FirebaseCollections.contentReports,
        sourceTag: 'admin_review.content_reports_open',
        filters: <FirestoreFilter>[FirestoreFilter(field: 'status', op: FirestoreFilterOp.isEqualTo, value: 'open')],
        orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
        isStream: true,
      ),
      _toDocument,
    );
  }

  Future<void> markContentReportReviewed(String reportDocId, {String? resolution}) async {
    await _client.updateDoc(FirebaseCollections.contentReports, reportDocId, <String, dynamic>{
      'status': 'reviewed',
      'reviewedAt': DateTime.now().toUtc(),
      if (resolution != null && resolution.isNotEmpty) 'resolution': resolution,
    }, sourceTag: 'admin_review.mark_content_report_reviewed');
  }

  /// Returns true if the wall existed and was rejected; false if it was already missing.
  Future<bool> rejectWallByFirestoreDocumentId(String wallDocId, {required String reason}) async {
    final FirestoreDocument? wall = await _client.getById<FirestoreDocument>(
      FirebaseCollections.walls,
      wallDocId,
      _toDocument,
      sourceTag: 'admin_review.reject_wall_by_doc_id',
    );
    if (wall == null) {
      return false;
    }
    await rejectWall(wall, reason: reason);
    return true;
  }

  Future<void> approveWall(FirestoreDocument wall) {
    final Map<String, dynamic>? notification = _notification(
      email: wall.email,
      title: 'Wallpaper Approved',
      body: 'Your wallpaper "${wall.payload['title'] ?? ''}" is now live!',
      imageUrl: wall.wallpaperThumb,
    );
    final List<String> collections = wall.collections;
    return _client.runBatch((FirestoreBatch batch) async {
      batch.updateDoc(FirebaseCollections.walls, wall.id, <String, dynamic>{
        'review': true,
        'collections': collections.isEmpty ? <String>['community'] : collections,
        'reviewedAt': DateTime.now().toUtc(),
        'createdAt': DateTime.now().toUtc(),
      });
      if (notification != null) {
        batch.addDoc(FirebaseCollections.notifications, notification);
      }
    }, sourceTag: 'admin_review.approve_wall');
  }

  Future<void> rejectWall(FirestoreDocument wall, {required String reason}) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      ...wall.data(),
      'rejectionReason': reason,
      'rejectedAt': DateTime.now().toUtc(),
    };
    await _client.runTransaction<void>(
      (FirestoreTransaction transaction) async {
        transaction.setDoc(FirebaseCollections.rejectedWalls, wall.id, payload);
        transaction.deleteDoc(FirebaseCollections.walls, wall.id);
      },
      sourceTag: 'admin_review.reject_wall',
      collection: FirebaseCollections.walls,
      docId: wall.id,
    );

    final Map<String, dynamic>? notification = _notification(
      email: wall.email,
      title: 'Wallpaper Rejected',
      body: reason,
      imageUrl: wall.wallpaperThumb,
    );
    if (notification == null) {
      return;
    }
    try {
      await _client.addDoc(
        FirebaseCollections.notifications,
        notification,
        sourceTag: 'admin_review.reject_wall.notify',
      );
    } catch (error, stackTrace) {
      logger.w('Rejection notification failed', tag: 'AdminReview', error: error, stackTrace: stackTrace);
    }
  }

  /// Puts a rejected wall back in review exactly as it was loaded and drops its rejection record.
  Future<void> undoRejectWall(FirestoreDocument wall) {
    return _client.runTransaction<void>(
      (FirestoreTransaction transaction) async {
        transaction.setDoc(FirebaseCollections.walls, wall.id, wall.data());
        transaction.deleteDoc(FirebaseCollections.rejectedWalls, wall.id);
      },
      sourceTag: 'admin_review.undo_reject_wall',
      collection: FirebaseCollections.walls,
      docId: wall.id,
    );
  }

  /// Sends an approved wall back to review with the values it had before approval.
  Future<void> undoApproveWall(FirestoreDocument wall) {
    return _client.updateDoc(FirebaseCollections.walls, wall.id, <String, dynamic>{
      'review': false,
      'collections': wall.collections,
      if (wall.payload['createdAt'] != null) 'createdAt': wall.payload['createdAt'],
    }, sourceTag: 'admin_review.undo_approve_wall');
  }

  static Map<String, dynamic>? _notification({
    required String email,
    required String title,
    required String body,
    required String imageUrl,
  }) {
    if (email.isEmpty) {
      return null;
    }
    return <String, dynamic>{
      'modifier': email,
      'notification': <String, dynamic>{'title': title, 'body': body},
      'data': <String, dynamic>{
        'pageName': '',
        'arguments': const <Object?>[],
        'url': '',
        'imageUrl': imageUrl,
        'route': 'announcement',
      },
      'createdAt': DateTime.now().toUtc(),
    };
  }
}
