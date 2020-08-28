import 'package:Prism/main.dart' as main;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

Firestore firestore = Firestore.instance;
void createRecord(
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
  });
  if (main.prefs.get('premium') == true) {
    toasts.codeSend("Succesfully uploaded");
  } else {
    toasts.codeSend("Your post is submitted, and is under review.");
  }
}
