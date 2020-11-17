import 'package:Prism/main.dart' as main;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:intl/intl.dart';

Firestore firestore = Firestore.instance;
Future<void> createRecord(
    String id,
    String wallpaperProvider,
    String wallpaperThumb,
    String wallpaperUrl,
    String wallpaperResolution,
    String wallpaperSize,
    String wallpaperCategory,
    String wallpaperDesc,
    bool review) async {
  await firestore.collection("walls").add({
    'by': main.prefs.get('name'),
    'email': main.prefs.get('email'),
    'userPhoto': main.prefs.get('googleimage'),
    'id': id,
    'wallpaper_provider': wallpaperProvider,
    'wallpaper_thumb': wallpaperThumb,
    'wallpaper_url': wallpaperUrl,
    'resolution': wallpaperResolution,
    'size': wallpaperSize,
    'category': wallpaperCategory,
    'desc': wallpaperDesc,
    'review': review,
    'createdAt': DateTime.now(),
    'collections': ["community"],
    'twitter': main.prefs.get('twitter') ?? "",
    'instagram': main.prefs.get('instagram') ?? "",
  });
  int wallsUploaded = main.prefs.get("wallsUploaded") as int ?? 0;
  if (main.prefs.get('date') !=
      DateFormat("yy-MM-dd").format(
        DateTime.now(),
      )) {
    wallsUploaded = 0;
  }
  main.prefs.put(
    'date',
    DateFormat("yy-MM-dd").format(
      DateTime.now(),
    ),
  );
  wallsUploaded++;
  main.prefs.put("wallsUploaded", wallsUploaded);
  if (wallsUploaded > 5) {
    toasts.codeSend("Please try to upload less than 5 walls a day.");
  }
  if (main.prefs.get('premium') == true) {
    toasts.codeSend("Succesfully uploaded");
  } else {
    toasts.codeSend("Your wall is submitted, and is under review.");
  }
}

Future<void> createSetup(
    String id,
    String imageURL,
    String wallpaperProvider,
    String wallpaperThumb,
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
    bool review) async {
  await firestore.collection("setups").add({
    'by': main.prefs.get('name'),
    'email': main.prefs.get('email'),
    'userPhoto': main.prefs.get('googleimage'),
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
    'created_at': DateTime.now(),
    'twitter': main.prefs.get('twitter') ?? "",
    'instagram': main.prefs.get('instagram') ?? "",
    'wall_id': wallId
  });
  toasts.codeSend("Your setup is submitted, and is under review.");
}
