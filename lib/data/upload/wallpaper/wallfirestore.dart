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
  await firestore.collection("walls2").add({
    'by': main.prefs.getString('name'),
    'email': main.prefs.getString('email'),
    'userPhoto': main.prefs.getString('googleimage'),
    'id': id,
    'wallpaper_provider': wallpaperProvider,
    'wallpaper_thumb': wallpaperThumb,
    'wallpaper_url': wallpaperUrl,
    'resolution': wallpaperResolution,
    'size': wallpaperSize,
    'category': wallpaperCategory,
    'desc': wallpaperDesc,
    'review': review,
  });
  toasts.codeSend("Your post is submitted, and is under review.");
}
