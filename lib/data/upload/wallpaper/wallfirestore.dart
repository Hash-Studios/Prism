import 'dart:convert';
import 'package:Prism/gitkey.dart';
import 'package:Prism/main.dart' as main;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:Prism/global/globals.dart' as globals;

FirebaseFirestore firestore = FirebaseFirestore.instance;
Future<void> createRecord(
    String? id,
    String? wallpaperProvider,
    String? wallpaperThumb,
    String? wallpaperUrl,
    String? wallpaperResolution,
    String? wallpaperSize,
    String? wallpaperCategory,
    String? wallpaperDesc,
    dynamic review) async {
  int dailyWallUpload =
      main.prefs.get("dailyWallUpload", defaultValue: 0) as int;
  if (main.prefs.get('date') !=
      DateFormat("yy-MM-dd").format(
        DateTime.now(),
      )) {
    dailyWallUpload = 0;
  }
  main.prefs.put(
    'date',
    DateFormat("yy-MM-dd").format(
      DateTime.now(),
    ),
  );
  dailyWallUpload++;
  main.prefs.put("dailyWallUpload", dailyWallUpload);
  if (dailyWallUpload > 5) {
    toasts.codeSend("Please try to upload less than 5 walls a day.");
  }
  await firestore.collection("walls").add({
    'by': globals.prismUser.name,
    'email': globals.prismUser.email,
    'userPhoto': globals.prismUser.profilePhoto,
    'id': id,
    'wallpaper_provider': wallpaperProvider,
    'wallpaper_thumb': wallpaperThumb,
    'wallpaper_url': wallpaperUrl,
    'resolution': wallpaperResolution,
    'size': wallpaperSize,
    'category': wallpaperCategory,
    'desc': wallpaperDesc,
    'review': review,
    'createdAt': DateTime.now().toUtc(),
    'collections': ["community"],
  });
  if (globals.prismUser.premium == true) {
    http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'key=$fcmServerToken',
      },
      body: jsonEncode(
        <String, dynamic>{
          'notification': <String, dynamic>{
            'title': '🎉 New Premium Wall for review!',
            'body':
                'New Post by ${globals.prismUser.username} is up for review.',
            'color': "#e57697",
            'image': wallpaperThumb,
            'android_channel_id': "posts",
          },
          'priority': 'high',
          'data': <String, dynamic>{
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'id': '1',
            'status': 'done'
          },
          'to': "/topics/${"maurya.abhay30".split("@")[0]}"
        },
      ),
    );
    http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'key=$fcmServerToken',
      },
      body: jsonEncode(
        <String, dynamic>{
          'notification': <String, dynamic>{
            'title': '🎉 New Premium Wall for review!',
            'body':
                'New Post by ${globals.prismUser.username} is up for review.',
            'color': "#e57697",
            'image': wallpaperThumb,
            'android_channel_id': "posts",
          },
          'priority': 'high',
          'data': <String, dynamic>{
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'id': '1',
            'status': 'done'
          },
          'to': "/topics/${"akshaymaurya3006".split("@")[0]}"
        },
      ),
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
    bool? review) async {
  await firestore.collection("setups").add({
    'by': globals.prismUser.name,
    'email': globals.prismUser.email,
    'userPhoto': globals.prismUser.profilePhoto,
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
    'wall_id': wallId
  });
  if (globals.prismUser.loggedIn == true && globals.prismUser.premium == true) {
    http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'key=$fcmServerToken',
      },
      body: jsonEncode(
        <String, dynamic>{
          'notification': <String, dynamic>{
            'title': '🎉 New Premium Setup for review!',
            'body':
                'New Post by ${globals.prismUser.username} is up for review.',
            'color': "#e57697",
            'image': imageURL,
            'android_channel_id': "posts",
          },
          'priority': 'high',
          'data': <String, dynamic>{
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'id': '1',
            'status': 'done'
          },
          'to': "/topics/${"maurya.abhay30".split("@")[0]}"
        },
      ),
    );
    http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'key=$fcmServerToken',
      },
      body: jsonEncode(
        <String, dynamic>{
          'notification': <String, dynamic>{
            'title': '🎉 New Premium Setup for review!',
            'body':
                'New Post by ${globals.prismUser.username} is up for review.',
            'color': "#e57697",
            'image': imageURL,
            'android_channel_id': "posts",
          },
          'priority': 'high',
          'data': <String, dynamic>{
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'id': '1',
            'status': 'done'
          },
          'to': "/topics/${"akshaymaurya3006".split("@")[0]}"
        },
      ),
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
    bool? review) async {
  await firestore.collection("setups").doc(setupDocId).update({
    'by': globals.prismUser.name,
    'email': globals.prismUser.email,
    'userPhoto': globals.prismUser.profilePhoto,
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
    'wall_id': wallId
  });
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
  await firestore.collection("draftSetups").doc(id).set({
    'by': globals.prismUser.name,
    'email': globals.prismUser.email,
    'userPhoto': globals.prismUser.profilePhoto,
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
  });
  toasts.codeSend("Draft saved!");
}
