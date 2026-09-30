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
    return _watchPending(FirebaseCollections.walls, 'admin_review.pending_walls', 'createdAt');
  }

  Stream<List<FirestoreDocument>> watchPendingSetups() {
    return _watchPending(FirebaseCollections.setups, 'admin_review.pending_setups', 'created_at');
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

  Stream<List<FirestoreDocument>> _watchPending(String collection, String sourceTag, String orderField) {
    return _client.watchQuery<FirestoreDocument>(
      FirestoreQuerySpec(
        collection: collection,
        sourceTag: sourceTag,
        filters: const <FirestoreFilter>[
          FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: false),
        ],
        orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: orderField, descending: true)],
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

  Future<void> rejectWall(FirestoreDocument wall, {required String reason}) {
    return _reject(
      wall,
      reason: reason,
      liveCollection: FirebaseCollections.walls,
      rejectedCollection: FirebaseCollections.rejectedWalls,
      title: 'Wallpaper Rejected',
      imageUrl: wall.wallpaperThumb,
      sourceTag: 'admin_review.reject_wall',
    );
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

  Future<void> approveSetup(FirestoreDocument setup) {
    final Map<String, dynamic>? notification = _notification(
      email: setup.email,
      title: 'Setup Approved',
      body: 'Your setup has been approved and is now live.',
      imageUrl: setup.image,
    );
    return _client.runBatch((FirestoreBatch batch) async {
      batch.updateDoc(FirebaseCollections.setups, setup.id, <String, dynamic>{
        'review': true,
        'reviewedAt': DateTime.now().toUtc(),
        'created_at': DateTime.now().toUtc(),
      });
      if (notification != null) {
        batch.addDoc(FirebaseCollections.notifications, notification);
      }
    }, sourceTag: 'admin_review.approve_setup');
  }

  Future<void> rejectSetup(FirestoreDocument setup, {required String reason}) {
    return _reject(
      setup,
      reason: reason,
      liveCollection: FirebaseCollections.setups,
      rejectedCollection: FirebaseCollections.rejectedSetups,
      title: 'Setup Rejected',
      imageUrl: setup.image,
      sourceTag: 'admin_review.reject_setup',
    );
  }

  Future<void> _reject(
    FirestoreDocument doc, {
    required String reason,
    required String liveCollection,
    required String rejectedCollection,
    required String title,
    required String imageUrl,
    required String sourceTag,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      ...doc.data(),
      'rejectionReason': reason,
      'rejectedAt': DateTime.now().toUtc(),
    };
    await _client.runTransaction<void>(
      (FirestoreTransaction transaction) async {
        transaction.setDoc(rejectedCollection, doc.id, payload);
        transaction.deleteDoc(liveCollection, doc.id);
      },
      sourceTag: sourceTag,
      collection: liveCollection,
      docId: doc.id,
    );

    final Map<String, dynamic>? notification = _notification(
      email: doc.email,
      title: title,
      body: reason,
      imageUrl: imageUrl,
    );
    if (notification == null) {
      return;
    }
    try {
      await _client.addDoc(FirebaseCollections.notifications, notification, sourceTag: '$sourceTag.notify');
    } catch (error, stackTrace) {
      logger.w('Rejection notification failed', tag: 'AdminReview', error: error, stackTrace: stackTrace);
    }
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
