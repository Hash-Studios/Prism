import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/upload/wallpaper/wall_submission.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

export 'package:Prism/data/upload/wallpaper/wall_submission.dart';

final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();

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
  dynamic review, {
  List<String>? wallpaperTags,
  bool isAiGenerated = false,
  String? aiGenerationId,
  String? aiProvider,
  String? aiModel,
  String? aiOriginalImageUrl,
  String? aiPrompt,
  String? aiStylePreset,
}) async {
  final user = app_state.prismUser;
  final bool isPremium = user.premium;
  final WallSubmissionResult result = await submitWallRecord(
    isPremium: isPremium,
    hasFreeQuota: UploadQuota.hasFreeUploadQuotaRemaining,
    consumeFreeQuota: () async {
      UploadQuota.incrementWeeklyUploads();
      user.uploadsWeekStart = _settingsLocal.get<String>('uploadsWeekStart', defaultValue: '').trim();
      user.uploadsThisWeek = UploadQuota.currentUploadsThisWeek();
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
    toasts.codeSend('Free users can upload ${UploadQuota.freeUploadsPerWeek} wallpapers per week.');
    return result;
  }
  toasts.codeSend('Your wall is submitted and is under review.');
  return result;
}

Future<void> createSetup(
  String? id,
  String? imageURL,
  String? wallpaperProvider,
  String? wallpaperThumb,
  dynamic wallpaperUrl,
  String iconName,
  String iconURL,
  String widgetName,
  String widgetURL,
  String widgetName2,
  String widgetURL2,
  String setupName,
  String setupDesc,
  String wallId,
  bool? review,
) async {
  await firestoreClient.addDoc(FirebaseCollections.setups, {
    'by': app_state.prismUser.name,
    'email': app_state.prismUser.email,
    'userPhoto': app_state.prismUser.profilePhoto,
    'id': id,
    'image': imageURL,
    'wallpaper_provider': wallpaperProvider,
    'wallpaper_thumb': wallpaperThumb,
    'wallpaper_url': wallpaperUrl,
    'icon': iconName,
    'icon_url': iconURL,
    'widget': widgetName,
    'widget_url': widgetURL,
    'widget2': widgetName2,
    'widget_url2': widgetURL2,
    'name': setupName,
    'desc': setupDesc,
    'review': review,
    'created_at': DateTime.now().toUtc(),
    'wall_id': wallId,
  }, sourceTag: 'upload.createSetup');
  toasts.codeSend("Your setup is submitted, and is under review.");
}

Future<void> updateSetup(
  String setupDocId,
  String? id,
  String? imageURL,
  String? wallpaperProvider,
  String? wallpaperThumb,
  dynamic wallpaperUrl,
  String iconName,
  String iconURL,
  String widgetName,
  String widgetURL,
  String widgetName2,
  String widgetURL2,
  String setupName,
  String setupDesc,
  String wallId,
  bool? review,
) async {
  await firestoreClient.setDoc(
    FirebaseCollections.setups,
    setupDocId,
    {
      'by': app_state.prismUser.name,
      'email': app_state.prismUser.email,
      'userPhoto': app_state.prismUser.profilePhoto,
      'id': id,
      'image': imageURL,
      'wallpaper_provider': wallpaperProvider,
      'wallpaper_thumb': wallpaperThumb,
      'wallpaper_url': wallpaperUrl,
      'icon': iconName,
      'icon_url': iconURL,
      'widget': widgetName,
      'widget_url': widgetURL,
      'widget2': widgetName2,
      'widget_url2': widgetURL2,
      'name': setupName,
      'desc': setupDesc,
      'review': review,
      'created_at': DateTime.now().toUtc(),
      'wall_id': wallId,
    },
    merge: true,
    sourceTag: 'upload.updateSetup',
  );
  toasts.codeSend("Your setup is edited, and is under review.");
}

Future<void> createDraftSetup(
  String? id,
  String? imageURL,
  String? wallpaperProvider,
  String? wallpaperThumb,
  dynamic wallpaperUrl,
  String? iconName,
  String? iconURL,
  String? widgetName,
  String? widgetURL,
  String? widgetName2,
  String? widgetURL2,
  String? setupName,
  String? setupDesc,
  String? wallId,
) async {
  await firestoreClient.setDoc(FirebaseCollections.draftSetups, id!, {
    'by': app_state.prismUser.name,
    'email': app_state.prismUser.email,
    'userPhoto': app_state.prismUser.profilePhoto,
    'id': id,
    'image': imageURL,
    'wallpaper_provider': wallpaperProvider,
    'wallpaper_thumb': wallpaperThumb,
    'wallpaper_url': wallpaperUrl,
    'icon': iconName,
    'icon_url': iconURL,
    'widget': widgetName,
    'widget_url': widgetURL,
    'widget2': widgetName2,
    'widget_url2': widgetURL2,
    'name': setupName,
    'desc': setupDesc,
    'review': false,
    'created_at': DateTime.now().toUtc(),
    'wall_id': wallId,
  }, sourceTag: 'upload.createDraftSetup');
  toasts.codeSend("Draft saved!");
}
