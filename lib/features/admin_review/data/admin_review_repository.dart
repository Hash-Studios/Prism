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

  Future<void> approveWall(FirestoreDocument wall) async {
    final Map<String, dynamic> payload = Map<String, dynamic>.from(wall.data());
    final List<dynamic> collections = payload['collections'] as List<dynamic>? ?? <dynamic>[];
    await firestoreClient.updateDoc(FirebaseCollections.walls, wall.id, <String, dynamic>{
      'review': true,
      'collections': collections.isEmpty ? <String>['community'] : collections,
      'reviewedAt': DateTime.now().toUtc(),
    }, sourceTag: 'admin_review.approve_wall');
    // The onWallApproved Cloud Function handles the push notification and
    // writes the in-app notification doc when review transitions to true.
  }

  Future<void> rejectWall(FirestoreDocument wall, {required String reason}) async {
    final Map<String, dynamic> payload = Map<String, dynamic>.from(wall.data());
    payload['rejectionReason'] = reason;
    payload['rejectedAt'] = DateTime.now().toUtc();

    await firestoreClient.addDoc(
      FirebaseCollections.rejectedWalls,
      payload,
      sourceTag: 'admin_review.reject_wall.archive',
    );
    await firestoreClient.deleteDoc(FirebaseCollections.walls, wall.id, sourceTag: 'admin_review.reject_wall.delete');

    await _sendUserNotification(
      modifier: _safeString(payload['email']),
      title: 'Wallpaper Rejected',
      body: reason,
      imageUrl: _safeString(payload['wallpaper_thumb']),
      route: 'announcement',
    );
  }

  Future<void> approveSetup(FirestoreDocument setup) async {
    final Map<String, dynamic> payload = Map<String, dynamic>.from(setup.data());
    await firestoreClient.updateDoc(FirebaseCollections.setups, setup.id, <String, dynamic>{
      'review': true,
      'reviewedAt': DateTime.now().toUtc(),
    }, sourceTag: 'admin_review.approve_setup');

    await _sendUserNotification(
      modifier: _safeString(payload['email']),
      title: 'Setup Approved',
      body: 'Your setup has been approved and is now live.',
      imageUrl: _safeString(payload['image']),
      route: 'announcement',
    );
  }

  Future<void> rejectSetup(FirestoreDocument setup, {required String reason}) async {
    final Map<String, dynamic> payload = Map<String, dynamic>.from(setup.data());
    payload['rejectionReason'] = reason;
    payload['rejectedAt'] = DateTime.now().toUtc();

    await firestoreClient.addDoc(
      FirebaseCollections.rejectedSetups,
      payload,
      sourceTag: 'admin_review.reject_setup.archive',
    );
    await firestoreClient.deleteDoc(
      FirebaseCollections.setups,
      setup.id,
      sourceTag: 'admin_review.reject_setup.delete',
    );

    await _sendUserNotification(
      modifier: _safeString(payload['email']),
      title: 'Setup Rejected',
      body: reason,
      imageUrl: _safeString(payload['image']),
      route: 'announcement',
    );
  }

  Future<void> _sendUserNotification({
    required String modifier,
    required String title,
    required String body,
    required String imageUrl,
    String route = '',
    String wallId = '',
  }) async {
    if (modifier.isEmpty) {
      return;
    }

    await firestoreClient.addDoc(FirebaseCollections.notifications, <String, dynamic>{
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
    }, sourceTag: 'admin_review.user_notification');
  }

  String _safeString(Object? value) => value?.toString() ?? '';
}
