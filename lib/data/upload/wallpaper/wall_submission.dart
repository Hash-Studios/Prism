import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/logger/logger.dart';

enum WallSubmissionResult { submitted, quotaExceeded }

Future<WallSubmissionResult> submitWallRecord({
  required bool isPremium,
  required bool hasFreeQuota,
  required void Function() consumeFreeQuota,
  required FirestoreClient firestoreClient,
  required Map<String, dynamic> record,
  required Future<void> Function() awardFirstUpload,
}) async {
  if (!isPremium && !hasFreeQuota) {
    return WallSubmissionResult.quotaExceeded;
  }

  await firestoreClient.addDoc(FirebaseCollections.walls, record, sourceTag: 'upload.createWall');

  if (!isPremium) {
    try {
      consumeFreeQuota();
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
}
