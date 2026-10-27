import 'package:Prism/core/platform/pigeon/prism_share_api.g.dart';
import 'package:Prism/env/env.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Meta "Sharing to Stories" contract for a background image.
InstagramStoryTarget instagramStoryTarget(String appId) => InstagramStoryTarget(
  appId: appId,
  iosUrl: Uri(scheme: 'instagram-stories', host: 'share', queryParameters: {'source_application': appId}).toString(),
  iosPasteboardKey: 'com.instagram.sharedSticker.backgroundImage',
  androidAction: 'com.instagram.share.ADD_TO_STORY',
  androidPackage: 'com.instagram.android',
  androidAppIdExtra: 'source_application',
  mimeType: 'image/png',
);

class InstagramStories {
  const InstagramStories._();

  @visibleForTesting
  static PrismShareHostApi api = PrismShareHostApi();

  @visibleForTesting
  static String appId = Env.metaAppId;

  /// True only when the Meta app ID is set and Instagram can take a story.
  static Future<bool> available() async {
    if (appId.trim().isEmpty) return false;
    try {
      return await api.canShareInstagramStory(instagramStoryTarget(appId.trim()));
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> share(String imagePath) async {
    if (appId.trim().isEmpty) return false;
    try {
      return await api.shareInstagramStory(instagramStoryTarget(appId.trim()), imagePath);
    } on PlatformException {
      return false;
    }
  }
}
