import 'dart:async';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
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
    if (!isPremium && !hasFreeQuota()) {
      return WallSubmissionResult.quotaExceeded;
    }

    await firestoreClient.addDoc(FirebaseCollections.walls, record, sourceTag: 'upload.createWall');

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
