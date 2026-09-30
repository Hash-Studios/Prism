import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/upload/wallpaper/setup_submission.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

Future<void> createRecord(
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
}) async {
  if (!app_state.prismUser.premium && !UploadQuota.hasFreeUploadQuotaRemaining()) {
    toasts.codeSend("Free users can upload ${UploadQuota.freeUploadsPerWeek} wallpapers per week.");
    return;
  }
  if (!app_state.prismUser.premium) {
    UploadQuota.incrementWeeklyUploads();
    app_state.prismUser.uploadsWeekStart = UploadQuota.storedWeekStart;
    app_state.prismUser.uploadsThisWeek = UploadQuota.currentUploadsThisWeek();
    app_state.persistPrismUser();
    if (app_state.prismUser.id.trim().isNotEmpty) {
      firestoreClient.updateDoc(FirebaseCollections.usersV2, app_state.prismUser.id, {
        'uploadsWeekStart': app_state.prismUser.uploadsWeekStart,
        'uploadsThisWeek': app_state.prismUser.uploadsThisWeek,
      }, sourceTag: 'upload.weekly_quota_sync');
    }
  }
  await firestoreClient.addDoc(FirebaseCollections.walls, {
    'by': app_state.prismUser.name,
    'email': app_state.prismUser.email,
    'userPhoto': app_state.prismUser.profilePhoto,
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
    'collections': ["community"],
    if (wallpaperTags != null) 'tags': wallpaperTags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList(),
    'isAiGenerated': isAiGenerated,
    if (aiGenerationId != null && aiGenerationId.trim().isNotEmpty) 'aiGenerationId': aiGenerationId,
    if (aiProvider != null && aiProvider.trim().isNotEmpty) 'aiProvider': aiProvider,
    if (aiModel != null && aiModel.trim().isNotEmpty) 'aiModel': aiModel,
    if (aiOriginalImageUrl != null && aiOriginalImageUrl.trim().isNotEmpty) 'aiOriginalImageUrl': aiOriginalImageUrl,
    if (aiPrompt != null && aiPrompt.trim().isNotEmpty) 'aiPrompt': aiPrompt,
    if (aiStylePreset != null && aiStylePreset.trim().isNotEmpty) 'aiStylePreset': aiStylePreset,
  }, sourceTag: 'upload.createWall');
  await CoinsService.instance.maybeAwardFirstWallpaperUpload();
  if (app_state.prismUser.premium) {
    toasts.codeSend("Succesfully uploaded");
  } else {
    toasts.codeSend("Your wall is submitted, and is under review.");
  }
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
  toasts.codeSend("Your setup is submitted, and is under review.");
}

Future<void> updateSetup(String setupDocId, SetupSubmission setup) async {
  await firestoreClient.setDoc(
    FirebaseCollections.setups,
    setupDocId,
    _setupPayload(setup),
    merge: true,
    sourceTag: 'upload.updateSetup',
  );
  toasts.codeSend("Your setup is edited, and is under review.");
}

Future<void> createDraftSetup(SetupSubmission setup) async {
  await firestoreClient.setDoc(
    FirebaseCollections.draftSetups,
    setup.id,
    _setupPayload(setup),
    sourceTag: 'upload.createDraftSetup',
  );
  toasts.codeSend("Draft saved!");
}
