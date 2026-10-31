import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:Prism/features/wallpaper_upload/data/resubmission_repository.dart';
import 'package:Prism/logger/logger.dart';

class SubmitResubmission {
  SubmitResubmission(this._repository);
  factory SubmitResubmission.fromGetIt() => SubmitResubmission(ResubmissionRepository(firestoreClient));
  final ResubmissionRepository _repository;

  Future<ResubmissionAdmission> call({
    required String ownerUid,
    required String operationId,
    required String rejectedDocId,
    required GitHubContent original,
    required GitHubContent thumbnail,
    required SubmissionMetadata metadata,
    required String resolution,
    required String size,
    void Function(CoinMutationResult result, String ownerUid)? onUploadAward,
  }) async {
    if (!app_state.prismUser.loggedIn || app_state.prismUser.id != ownerUid) {
      throw StateError('The upload owner changed.');
    }
    final admission = await _repository.submit(
      operationId: operationId,
      rejectedDocId: rejectedDocId,
      original: original,
      thumbnail: thumbnail,
      metadata: metadata,
      resolution: resolution,
      size: size,
    );
    if (app_state.prismUser.id == ownerUid && app_state.prismUser.loggedIn) {
      try {
        if (!app_state.prismUser.premium) {
          await UploadQuota.incrementWeeklyUploads(ownerUid: ownerUid, operationId: operationId);
          if (app_state.prismUser.id != ownerUid || !app_state.prismUser.loggedIn) return admission;
          app_state.prismUser.uploadsThisWeek = UploadQuota.currentUploadsThisWeek();
          app_state.prismUser.uploadsWeekStart = UploadQuota.storedWeekStart;
          await app_state.persistPrismUser();
        }
        if (app_state.prismUser.id == ownerUid && app_state.prismUser.loggedIn) {
          final result = await CoinsService.instance.maybeAwardFirstWallpaperUpload();
          if (app_state.prismUser.id == ownerUid &&
              app_state.prismUser.loggedIn &&
              result.success &&
              result.changed &&
              result.delta > 0) {
            onUploadAward?.call(result, ownerUid);
          }
        }
      } catch (error, stackTrace) {
        logger.w('Resubmission completed but local success hooks failed', error: error, stackTrace: stackTrace);
      }
    }
    return admission;
  }
}
