import 'package:flutter/foundation.dart';

/// Where a setup's wallpaper comes from. [firestoreValue] is the `wallpaper_url` field.
@immutable
sealed class SetupWallpaperInput {
  const SetupWallpaperInput();

  Object get firestoreValue;

  String get wallId => '';

  bool get isFilled;
}

final class LinkWallpaper extends SetupWallpaperInput {
  const LinkWallpaper(this.url);

  final String url;

  @override
  Object get firestoreValue => url;

  @override
  bool get isFilled => url.isNotEmpty;
}

final class UploadedWallpaper extends SetupWallpaperInput {
  const UploadedWallpaper({required this.url, required this.id});

  final String url;
  final String id;

  @override
  Object get firestoreValue => url;

  @override
  String get wallId => id;

  @override
  bool get isFilled => true;
}

final class AppWallpaper extends SetupWallpaperInput {
  const AppWallpaper({required this.appName, required this.link, required this.wallName});

  final String appName;
  final String link;
  final String wallName;

  @override
  Object get firestoreValue => <String>[appName, link, wallName];

  @override
  bool get isFilled => appName.isNotEmpty && link.isNotEmpty;
}

/// The fields a user types into the setup form.
@immutable
class SetupDetails {
  const SetupDetails({
    this.setupName = '',
    this.setupDesc = '',
    this.iconName = '',
    this.iconUrl = '',
    this.widgetName = '',
    this.widgetUrl = '',
    this.widgetName2 = '',
    this.widgetUrl2 = '',
    this.wallpaper = const LinkWallpaper(''),
  });

  final String setupName;
  final String setupDesc;
  final String iconName;
  final String iconUrl;
  final String widgetName;
  final String widgetUrl;
  final String widgetName2;
  final String widgetUrl2;
  final SetupWallpaperInput wallpaper;

  bool get hasRequiredFields =>
      setupName.isNotEmpty && setupDesc.isNotEmpty && iconName.isNotEmpty && iconUrl.isNotEmpty && wallpaper.isFilled;
}

/// One setup document write: the form [details] plus the fields the screen owns.
@immutable
class SetupSubmission {
  const SetupSubmission({
    required this.id,
    required this.imageUrl,
    required this.wallpaperProvider,
    required this.wallpaperThumb,
    required this.review,
    required this.details,
  });

  final String id;
  final String? imageUrl;
  final String wallpaperProvider;
  final String wallpaperThumb;
  final bool review;
  final SetupDetails details;

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'image': imageUrl,
    'wallpaper_provider': wallpaperProvider,
    'wallpaper_thumb': wallpaperThumb,
    'wallpaper_url': details.wallpaper.firestoreValue,
    'icon': details.iconName,
    'icon_url': details.iconUrl,
    'widget': details.widgetName,
    'widget_url': details.widgetUrl,
    'widget2': details.widgetName2,
    'widget_url2': details.widgetUrl2,
    'name': details.setupName,
    'desc': details.setupDesc,
    'review': review,
    'wall_id': details.wallpaper.wallId,
  };
}
