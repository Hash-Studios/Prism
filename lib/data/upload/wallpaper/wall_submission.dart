import 'dart:async';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/logger/logger.dart';

enum WallSubmissionResult { submitted, quotaExceeded }

Future<void> _freeSubmissionTail = Future<void>.value();

Future<WallSubmissionResult> submitWallRecord({
  required bool isPremium,
  required bool Function() hasFreeQuota,
  required Future<void> Function() consumeFreeQuota,
  required FirestoreClient firestoreClient,
  required Map<String, dynamic> record,
  required Future<void> Function() awardFirstUpload,
  String? docId,
}) async {
  Completer<void>? release;
  if (!isPremium) {
    final Completer<void> current = Completer<void>();
    release = current;
    final Future<void> previous = _freeSubmissionTail;
    // ponytail: serializes free submissions in this app process; per-account locks if throughput matters.
    _freeSubmissionTail = current.future;
    await previous;
  }

  try {
    final bool alreadySubmitted =
        docId != null && await _alreadySubmittedByOwner(firestoreClient, docId, record['email']);

    if (!alreadySubmitted) {
      if (!isPremium && !hasFreeQuota()) {
        return WallSubmissionResult.quotaExceeded;
      }

      if (docId == null) {
        await firestoreClient.addDoc(FirebaseCollections.walls, record, sourceTag: 'upload.createWall');
      } else {
        await firestoreClient.setDoc(FirebaseCollections.walls, docId, record, sourceTag: 'upload.createWall');
      }

      if (!isPremium) {
        try {
          await consumeFreeQuota();
        } catch (error, stackTrace) {
          logger.w(
            'Could not update weekly upload quota after submission',
            tag: 'Upload',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    }

    try {
      await awardFirstUpload();
    } catch (error, stackTrace) {
      logger.w(
        'First wallpaper upload reward failed after submission',
        tag: 'Upload',
        error: error,
        stackTrace: stackTrace,
      );
    }

    return WallSubmissionResult.submitted;
  } finally {
    release?.complete();
  }
}

/// A retry must never overwrite a wall that already landed: it may have been reviewed since.
/// Rules refuse reads of a missing wall, so permission-denied means the id is free.
Future<bool> _alreadySubmittedByOwner(FirestoreClient firestoreClient, String docId, Object? email) async {
  try {
    final Map<String, dynamic>? existing = await firestoreClient.getById<Map<String, dynamic>>(
      FirebaseCollections.walls,
      docId,
      (Map<String, dynamic> data, String _) => data,
      sourceTag: 'upload.createWall.existing',
    );
    return existing != null && email is String && email.isNotEmpty && existing['email'] == email;
  } on FirestoreError catch (error) {
    if (error.code == 'permission-denied') {
      return false;
    }
    rethrow;
  }
}
