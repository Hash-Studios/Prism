import 'dart:convert';
import 'dart:typed_data';

import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/desktop_submission/domain/desktop_submit_failure.dart';
import 'package:Prism/features/desktop_submission/domain/entities/desktop_submission.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:injectable/injectable.dart';

/// Thrown by [DesktopSubmissionRepository.review] when the wall is no longer approved, so approve cannot go through.
class DesktopReviewWallUnavailable implements Exception {
  const DesktopReviewWallUnavailable();
}

@lazySingleton
class DesktopSubmissionRepository {
  DesktopSubmissionRepository(this._client) : _call = _callable;

  DesktopSubmissionRepository.withCaller(this._client, this._call);

  final FirestoreClient _client;
  final Future<Object?> Function(String name, Map<String, Object?> data) _call;

  /// Uploads are large, so `submitDesktopVersion` gets a longer timeout than the other callables.
  static Future<Object?> _callable(String name, Map<String, Object?> data) async {
    final Duration timeout = name == 'submitDesktopVersion'
        ? const Duration(seconds: 120)
        : const Duration(seconds: 30);
    return (await appFunctions
            .httpsCallable(name, options: cf.HttpsCallableOptions(timeout: timeout))
            .call<Object?>(data))
        .data;
  }

  Future<String> submit({required String wallDocId, required Uint8List bytes}) async {
    try {
      final Object? raw = await _call('submitDesktopVersion', <String, Object?>{
        'wallDocId': wallDocId,
        'contentBase64': base64Encode(bytes),
      });
      final Object? submissionId = raw is Map ? raw['submissionId'] : null;
      if (submissionId is! String) throw StateError('desktop-submit-response-invalid');
      return submissionId;
    } on cf.FirebaseFunctionsException catch (error) {
      throw DesktopSubmitException(_failureFor(error));
    } on Object {
      throw const DesktopSubmitException(DesktopSubmitFailure.failed);
    }
  }

  static DesktopSubmitFailure _failureFor(cf.FirebaseFunctionsException error) {
    switch (error.message) {
      case 'desktop-not-landscape':
        return DesktopSubmitFailure.notLandscape;
      case 'desktop-aspect-ratio':
        return DesktopSubmitFailure.wrongAspect;
      case 'desktop-too-small':
        return DesktopSubmitFailure.tooSmall;
      case 'desktop-image-invalid':
        return DesktopSubmitFailure.unreadable;
      case 'desktop-file-too-large':
        return DesktopSubmitFailure.tooLarge;
      case 'desktop-pending-exists':
        return DesktopSubmitFailure.alreadyPending;
      case 'desktop-not-owner':
      case 'desktop-wall-not-approved':
      case 'desktop-wall-not-found':
        return DesktopSubmitFailure.notAllowed;
    }
    switch (error.code) {
      case 'permission-denied':
        return DesktopSubmitFailure.notAllowed;
      case 'resource-exhausted':
        return DesktopSubmitFailure.rateLimited;
      default:
        return DesktopSubmitFailure.failed;
    }
  }

  Stream<bool> watchPendingForWall({required String wallDocId, required String uid}) {
    return _client
        .watchQuery<String>(
          FirestoreQuerySpec(
            collection: FirebaseCollections.desktopSubmissions,
            sourceTag: 'desktop_submission.pending_for_wall',
            filters: <FirestoreFilter>[
              FirestoreFilter(field: 'creatorUid', op: FirestoreFilterOp.isEqualTo, value: uid),
              FirestoreFilter(field: 'wallDocId', op: FirestoreFilterOp.isEqualTo, value: wallDocId),
              const FirestoreFilter(field: 'state', op: FirestoreFilterOp.isEqualTo, value: 'pending'),
            ],
            limit: 1,
            isStream: true,
          ),
          (Map<String, dynamic> _, String docId) => docId,
        )
        .map((List<String> ids) => ids.isNotEmpty);
  }

  Stream<List<DesktopSubmission>> watchReviewQueue() {
    return _client
        .watchQuery<DesktopSubmission?>(
          const FirestoreQuerySpec(
            collection: FirebaseCollections.desktopSubmissions,
            sourceTag: 'admin_review.desktop_submissions',
            filters: <FirestoreFilter>[
              FirestoreFilter(field: 'state', op: FirestoreFilterOp.isEqualTo, value: 'pending'),
            ],
            orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
            isStream: true,
          ),
          (Map<String, dynamic> data, String id) => DesktopSubmission.fromData(id, data),
        )
        .map(
          (List<DesktopSubmission?> submissions) => submissions.whereType<DesktopSubmission>().toList(growable: false),
        );
  }

  Future<void> review({required String submissionId, required bool approve, String? reason, String? reasonCode}) async {
    try {
      await _call('reviewDesktopSubmission', <String, Object?>{
        'submissionId': submissionId,
        'decision': approve ? 'approve' : 'reject',
        if (reason != null) 'reason': reason,
        if (reasonCode != null) 'reasonCode': reasonCode,
      });
    } on cf.FirebaseFunctionsException catch (error) {
      if (error.message == 'desktop-wall-unavailable') throw const DesktopReviewWallUnavailable();
      rethrow;
    }
  }
}
