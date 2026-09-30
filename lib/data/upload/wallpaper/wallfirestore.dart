import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/upload/wallpaper/setup_submission.dart';
import 'package:Prism/data/upload/wallpaper/wall_submission.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

export 'package:Prism/data/upload/wallpaper/wall_submission.dart';

Future<WallSubmissionResult> createRecord(
  String? id,
  String? wallpaperProvider,
  String? wallpaperThumb,
  String? wallpaperUrl,
  String? wallpaperResolution,
  String? wallpaperSize,
  String? wallpaperTitle,
  String? wallpaperCategory,
  String? wallpaperDesc,
  Object review, {
  List<String>? wallpaperTags,
  bool isAiGenerated = false,
  String? aiGenerationId,
  String? aiProvider,
  String? aiModel,
  String? aiOriginalImageUrl,
  String? aiPrompt,
  String? aiStylePreset,
  DateTime Function()? now,
}) async {
  final user = app_state.prismUser;
  final bool isPremium = user.premium;
  final DateTime Function() currentTime = now ?? DateTime.now;
  final WallSubmissionResult result = await submitWallRecord(
    isPremium: isPremium,
    hasFreeQuota: () => UploadQuota.hasFreeUploadQuotaRemaining(now: currentTime()),
    consumeFreeQuota: () async {
      await UploadQuota.incrementWeeklyUploads(now: currentTime());
      user.uploadsWeekStart = UploadQuota.storedWeekStart;
      user.uploadsThisWeek = UploadQuota.currentUploadsThisWeek(now: currentTime());
      final Future<void>? persistUser = app_state.prismUser.id == user.id ? app_state.persistPrismUser() : null;
      if (user.id.trim().isNotEmpty) {
        unawaited(
          firestoreClient
              .updateDoc(FirebaseCollections.usersV2, user.id, {
                'uploadsWeekStart': user.uploadsWeekStart,
                'uploadsThisWeek': user.uploadsThisWeek,
              }, sourceTag: 'upload.weekly_quota_sync')
              .catchError((Object error, StackTrace stackTrace) {
                logger.w('Could not sync weekly upload quota', tag: 'Upload', error: error, stackTrace: stackTrace);
              }),
        );
      }
      if (persistUser != null) await persistUser;
    },
    firestoreClient: firestoreClient,
    record: {
      'by': user.name,
      'email': user.email,
      'userPhoto': user.profilePhoto,
      'id': id,
      'wallpaper_provider': wallpaperProvider,
      'wallpaper_thumb': wallpaperThumb,
      'wallpaper_url': wallpaperUrl,
      'resolution': wallpaperResolution,
      'size': wallpaperSize,
      if (wallpaperTitle != null && wallpaperTitle.trim().isNotEmpty) 'title': wallpaperTitle.trim(),
      'category': wallpaperCategory,
      'desc': wallpaperDesc,
      'review': review,
      'createdAt': DateTime.now().toUtc(),
      'collections': ['community'],
      if (wallpaperTags != null) 'tags': wallpaperTags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList(),
      'isAiGenerated': isAiGenerated,
      if (aiGenerationId != null && aiGenerationId.trim().isNotEmpty) 'aiGenerationId': aiGenerationId,
      if (aiProvider != null && aiProvider.trim().isNotEmpty) 'aiProvider': aiProvider,
      if (aiModel != null && aiModel.trim().isNotEmpty) 'aiModel': aiModel,
      if (aiOriginalImageUrl != null && aiOriginalImageUrl.trim().isNotEmpty) 'aiOriginalImageUrl': aiOriginalImageUrl,
      if (aiPrompt != null && aiPrompt.trim().isNotEmpty) 'aiPrompt': aiPrompt,
      if (aiStylePreset != null && aiStylePreset.trim().isNotEmpty) 'aiStylePreset': aiStylePreset,
    },
    awardFirstUpload: () {
      if (app_state.prismUser.id != user.id) return Future<void>.value();
      return CoinsService.instance.maybeAwardFirstWallpaperUpload().then((_) {});
    },
  );

  if (result == WallSubmissionResult.quotaExceeded) {
    toasts.success('Free users can upload ${UploadQuota.freeUploadsPerWeek} wallpapers per week.');
    return result;
  }
  toasts.success('Your wall is submitted and is under review.');
  return result;
}

Map<String, dynamic> _setupPayload(SetupSubmission s) => {
  'by': app_state.prismUser.name,
  'email': app_state.prismUser.email,
  'userPhoto': app_state.prismUser.profilePhoto,
  ...s.toFirestore(),
  'created_at': DateTime.now().toUtc(),
};

Future<void> createSetup(SetupSubmission setup) async {
  await firestoreClient.addDoc(FirebaseCollections.setups, _setupPayload(setup), sourceTag: 'upload.createSetup');
  toasts.success("Your setup is submitted, and is under review.");
}

Future<void> updateSetup(String setupDocId, SetupSubmission setup) async {
  await firestoreClient.setDoc(
    FirebaseCollections.setups,
    setupDocId,
    _setupPayload(setup),
    merge: true,
    sourceTag: 'upload.updateSetup',
  );
  toasts.success("Your setup is edited, and is under review.");
}

Future<void> createDraftSetup(SetupSubmission setup) async {
  await firestoreClient.setDoc(
    FirebaseCollections.draftSetups,
    setup.id,
    _setupPayload(setup),
    sourceTag: 'upload.createDraftSetup',
  );
  toasts.success("Draft saved!");
}
