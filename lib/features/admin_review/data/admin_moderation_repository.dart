import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_sentinels.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/features/admin_review/biz/depth_override.dart';
import 'package:Prism/features/admin_review/biz/drop_reserve.dart';
import 'package:Prism/features/wallpaper_upload/data/repositories/wall_metadata_repository.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:Prism/features/wallpaper_upload/domain/usecases/wall_metadata_actions.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:injectable/injectable.dart';

@lazySingleton
class AdminModerationRepository {
  AdminModerationRepository(this._client) : _call = _callable;

  AdminModerationRepository.withCaller(this._client, this._call);

  final FirestoreClient _client;
  final WallMetadataCaller _call;
  final Map<String, String> _rejectionOperations = <String, String>{};
  final Map<String, ({String operationId, String revision, String reason})> _rejectionRequests = {};
  final Map<String, ({String operationId, String revision})> _undoRequests = {};

  late final WallMetadataActions metadataActions = WallMetadataActions(
    WallMetadataRepositoryImpl(_client, owner: () => (uid: '', email: ''), caller: _call),
  );

  static Future<Object?> _callable(String name, Map<String, Object?> data) async =>
      (await appFunctions
              .httpsCallable(name, options: cf.HttpsCallableOptions(timeout: const Duration(seconds: 30)))
              .call<Object?>(data))
          .data;

  Future<Map<String, dynamic>> _reviewContext(String id) async {
    final Object? raw = await _call('getWallResubmissionContext', <String, Object?>{
      'wallDocIds': <String>[id],
    });
    if (raw is! Map || raw['contexts'] is! Map || (raw['contexts'] as Map)[id] is! Map) {
      throw StateError('wall-review-context-unavailable');
    }
    return Map<String, dynamic>.from((raw['contexts'] as Map)[id] as Map);
  }

  static FirestoreDocument _toDocument(Map<String, dynamic> data, String id) => FirestoreDocument(id, data);

  Stream<List<FirestoreDocument>> watchPendingWalls() {
    return _client
        .watchQuery<FirestoreDocument>(
          const FirestoreQuerySpec(
            collection: FirebaseCollections.walls,
            sourceTag: 'admin_review.pending_walls',
            filters: <FirestoreFilter>[FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: false)],
            orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
            isStream: true,
          ),
          _toDocument,
        )
        .map((List<FirestoreDocument> walls) => walls.where((wall) => !isInDrop(wall)).toList(growable: false));
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

  /// The text of the request a pending wall says it fills, so the admin can check the match before approving.
  /// The creator writes `requestId` on the wall, so the text comes from the request itself.
  Future<String?> requestText(String requestId) async {
    if (requestId.isEmpty || requestId.contains('/')) return null;
    return _client.getById<String?>(
      FirebaseCollections.wallRequests,
      requestId,
      (Map<String, dynamic> data, String _) => data['text'] is String ? data['text'] as String : null,
      sourceTag: 'admin_review.request_text',
    );
  }

  /// onWallApproved writes the artist's inbox entry and push, so approval adds none here.
  /// A creator can write any `collections` or streak value on a pending wall. Approval therefore files the wall under
  /// `community` and removes the streak fields, unless the admin passes values.
  Future<void> approveWall(
    FirestoreDocument wall, {
    List<String>? collections,
    bool? streakExclusive,
    int? streakShopCoinCost,
  }) async {
    await _client.updateDoc(FirebaseCollections.walls, wall.id, <String, dynamic>{
      'review': true,
      'collections': collections == null || collections.isEmpty ? <String>['community'] : collections,
      'is_streak_exclusive': streakExclusive ?? FirestoreSentinels.delete(),
      'streak_shop_coin_cost': streakShopCoinCost ?? FirestoreSentinels.delete(),
      'reviewedAt': DateTime.now().toUtc(),
      'createdAt': DateTime.now().toUtc(),
    }, sourceTag: 'admin_review.approve_wall');
    final Object? requestId = wall.data()['requestId'];
    if (requestId is String && requestId.isNotEmpty) {
      analytics.track(
        WallRequestFilledEvent(
          filledBy: wall.data()['origin'] == 'studio' ? WallRequestFillerValue.studio : WallRequestFillerValue.creator,
        ),
      );
    }
  }

  Future<void> rejectWall(FirestoreDocument wall, {required String reason}) async {
    var request = _rejectionRequests[wall.id];
    if (request == null || request.reason != reason) {
      final Map<String, dynamic> context = await _reviewContext(wall.id);
      final Object? revision = context['wallRevision'];
      if (revision is! String) throw StateError('wall-review-conflict');
      request = (operationId: newWallMetadataOperationId(), revision: revision, reason: reason);
      _rejectionRequests[wall.id] = request;
    }
    // Only the server can capture Firestore createTime. It rereads current metadata and archives/deletes atomically.
    try {
      await _call('rejectWallForReview', <String, Object?>{
        'wallDocId': wall.id,
        'expectedWallRevision': request.revision,
        'expectedReview': wall.review,
        'rejectionOperationId': request.operationId,
        'reason': reason,
      });
    } on cf.FirebaseFunctionsException catch (error) {
      if (error.code == 'aborted' || error.code == 'failed-precondition') _rejectionRequests.remove(wall.id);
      rethrow;
    }
    _rejectionOperations[wall.id] = request.operationId;
    _rejectionRequests.remove(wall.id);
    _undoRequests.remove(wall.id);
    _client.invalidateQueryCache();

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

  /// Restores the committed rejection, never the stale queue card, and never overwrites a live wall.
  Future<void> undoRejectWall(FirestoreDocument wall) async {
    var request = _undoRequests[wall.id];
    if (request == null) {
      final String? rejectedOperation = _rejectionOperations[wall.id];
      if (rejectedOperation == null) throw StateError('wall-undo-conflict');
      final Map<String, dynamic> context = await _reviewContext(wall.id);
      final Object? revision = context['rejectionRevision'];
      if (revision is! String ||
          context['wallRevision'] != null ||
          context['hasAdmittedChild'] == true ||
          context['rejectionOperationId'] != rejectedOperation) {
        throw StateError('wall-undo-conflict');
      }
      request = (operationId: newWallMetadataOperationId(), revision: revision);
      _undoRequests[wall.id] = request;
    }
    await _call('undoWallRejection', <String, Object?>{
      'wallDocId': wall.id,
      'expectedRejectionRevision': request.revision,
      'operationId': request.operationId,
    });
    _rejectionRequests.remove(wall.id);
    _client.invalidateQueryCache();
  }

  /// Sets a Studio wall aside for the next weekly Drop. The planner picks it up on Monday.
  Future<void> reserveWallForDrop(FirestoreDocument wall) {
    return _client.updateDoc(FirebaseCollections.walls, wall.id, <String, dynamic>{
      'dropReserved': true,
    }, sourceTag: 'admin_review.reserve_wall_for_drop');
  }

  Future<void> undoReserveWallForDrop(FirestoreDocument wall) {
    return _client.updateDoc(FirebaseCollections.walls, wall.id, <String, dynamic>{
      'dropReserved': false,
    }, sourceTag: 'admin_review.undo_reserve_wall_for_drop');
  }

  /// Overrides the Depth Effect tier the detector chose. Only admins and the server write `walls.depth`.
  Future<void> setDepthTier(FirestoreDocument wall, WallDepthTier tier) {
    return _client.updateDoc(
      FirebaseCollections.walls,
      wall.id,
      depthOverrideUpdate(wall, tier),
      sourceTag: 'admin_review.set_depth_tier',
    );
  }

  /// Sends an approved wall back to review with the values it had before approval.
  Future<void> undoApproveWall(FirestoreDocument wall) {
    return _client.updateDoc(FirebaseCollections.walls, wall.id, <String, dynamic>{
      'review': false,
      'collections': wall.collections,
      if (wall.payload.containsKey('is_streak_exclusive')) 'is_streak_exclusive': wall.payload['is_streak_exclusive'],
      if (wall.payload.containsKey('streak_shop_coin_cost'))
        'streak_shop_coin_cost': wall.payload['streak_shop_coin_cost'],
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
        'push_kind': 'rejection',
      },
      'createdAt': DateTime.now().toUtc(),
    };
  }
}
