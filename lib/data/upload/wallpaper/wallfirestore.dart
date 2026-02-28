import 'dart:convert';

import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:http/http.dart' as http;

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
  if (!app_state.prismUser.premium && !UploadQuota.hasFreeUploadQuotaRemaining()) {
    toasts.codeSend("Free users can upload ${UploadQuota.freeUploadsPerWeek} wallpapers per week.");
    return;
  }
  if (!app_state.prismUser.premium) {
    UploadQuota.incrementWeeklyUploads();
    app_state.prismUser.uploadsWeekStart =
        (main.prefs.get('uploadsWeekStart', defaultValue: '') as String?)?.trim() ?? '';
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
  if (app_state.prismUser.premium == true) {
    http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'key=${Env.normalize(Env.fcmServerKey)}',
      },
      body: jsonEncode(<String, dynamic>{
        'notification': <String, dynamic>{
          'title': '🎉 New Premium Wall for review!',
          'body': 'New Post by ${app_state.prismUser.username} is up for review.',
          'color': "#e57697",
          'image': wallpaperThumb,
          'android_channel_id': "posts",
        },
        'priority': 'high',
        'data': <String, dynamic>{'click_action': 'FLUTTER_NOTIFICATION_CLICK', 'id': '1', 'status': 'done'},
        'to': "/topics/${"maurya.abhay30".split("@")[0]}",
      }),
    );
    http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'key=${Env.normalize(Env.fcmServerKey)}',
      },
      body: jsonEncode(<String, dynamic>{
        'notification': <String, dynamic>{
          'title': '🎉 New Premium Wall for review!',
          'body': 'New Post by ${app_state.prismUser.username} is up for review.',
          'color': "#e57697",
          'image': wallpaperThumb,
          'android_channel_id': "posts",
        },
        'priority': 'high',
        'data': <String, dynamic>{'click_action': 'FLUTTER_NOTIFICATION_CLICK', 'id': '1', 'status': 'done'},
        'to': "/topics/${"akshaymaurya3006".split("@")[0]}",
      }),
    );

    toasts.codeSend("Succesfully uploaded");
  } else {
    toasts.codeSend("Your wall is submitted, and is under review.");
  }
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
  if (app_state.prismUser.loggedIn == true && app_state.prismUser.premium == true) {
    http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'key=${Env.normalize(Env.fcmServerKey)}',
      },
      body: jsonEncode(<String, dynamic>{
        'notification': <String, dynamic>{
          'title': '🎉 New Premium Setup for review!',
          'body': 'New Post by ${app_state.prismUser.username} is up for review.',
          'color': "#e57697",
          'image': imageURL,
          'android_channel_id': "posts",
        },
        'priority': 'high',
        'data': <String, dynamic>{'click_action': 'FLUTTER_NOTIFICATION_CLICK', 'id': '1', 'status': 'done'},
        'to': "/topics/${"maurya.abhay30".split("@")[0]}",
      }),
    );
    http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'key=${Env.normalize(Env.fcmServerKey)}',
      },
      body: jsonEncode(<String, dynamic>{
        'notification': <String, dynamic>{
          'title': '🎉 New Premium Setup for review!',
          'body': 'New Post by ${app_state.prismUser.username} is up for review.',
          'color': "#e57697",
          'image': imageURL,
          'android_channel_id': "posts",
        },
        'priority': 'high',
        'data': <String, dynamic>{'click_action': 'FLUTTER_NOTIFICATION_CLICK', 'id': '1', 'status': 'done'},
        'to': "/topics/${"akshaymaurya3006".split("@")[0]}",
      }),
    );
  }
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
