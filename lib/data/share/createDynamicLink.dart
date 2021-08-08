import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/ui/widgets/popup/copyrightPopUp.dart';
import 'package:animations/animations.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/foundation.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:share/share.dart';

Future<String> createDynamicLink(
    String id, String provider, String? url, String thumbUrl) async {
  final DynamicLinkParameters parameters = DynamicLinkParameters(
      socialMetaTagParameters: SocialMetaTagParameters(
          title: "$id - Prism",
          imageUrl: Uri.parse(thumbUrl),
          description: "Check out this amazing wallpaper I got from Prism."),
      dynamicLinkParametersOptions: DynamicLinkParametersOptions(
          shortDynamicLinkPathLength: ShortDynamicLinkPathLength.short),
      uriPrefix: 'https://prismwallpapers.page.link',
      link: Uri.parse(
          'http://prism.hash.com/share?id=$id&provider=$provider&url=$url&thumb=$thumbUrl'),
      androidParameters: AndroidParameters(
        packageName: 'com.hash.prism',
        minimumVersion: 1,
      ),
      iosParameters: IosParameters(
        bundleId: 'com.hash.prism',
        minimumVersion: '1.0.1',
        appStoreId: '1405860595',
      ));
  final ShortDynamicLink shortDynamicLink = await parameters.buildShortLink();
  final Uri shortUrl = shortDynamicLink.shortUrl;
  Clipboard.setData(
      ClipboardData(text: "Hey check this out ➜ ${shortUrl.toString()}"));
  analytics.logShare(contentType: 'focussedMenu', itemId: id, method: 'link');
  toasts.codeSend("Sharing link copied!");
  logger.d(shortUrl.toString());
  return shortUrl.toString();
}

Future<void> createUserDynamicLink(String name, String username, String email,
    String bio, String userPhoto) async {
  final DynamicLinkParameters parameters = DynamicLinkParameters(
      socialMetaTagParameters: SocialMetaTagParameters(
          title: "$name (@$username)",
          imageUrl: Uri.parse(userPhoto),
          description:
              bio != "" ? bio : "Check out my walls & setups on Prism."),
      dynamicLinkParametersOptions: DynamicLinkParametersOptions(
          shortDynamicLinkPathLength: ShortDynamicLinkPathLength.short),
      uriPrefix: 'https://prismwallpapers.page.link',
      link: Uri.parse('http://prism.hash.com/user?email=$email'),
      androidParameters: AndroidParameters(
        packageName: 'com.hash.prism',
        minimumVersion: 1,
      ),
      iosParameters: IosParameters(
        bundleId: 'com.hash.prism',
        minimumVersion: '1.0.1',
        appStoreId: '1405860595',
      ));
  // final Uri shortUrl = await parameters.buildUrl();
  final ShortDynamicLink shortDynamicLink = await parameters.buildShortLink();
  final Uri shortUrl = shortDynamicLink.shortUrl;
  Clipboard.setData(ClipboardData(text: shortUrl.toString()));
  Share.share("Hey check out my profile on Prism ➜ $shortUrl");
  analytics.logShare(
      contentType: 'userShare', itemId: username, method: 'link');
  logger.d(shortUrl.toString());
}

Future<void> createSetupDynamicLink(
    String index, String name, String thumbUrl) async {
  final DynamicLinkParameters parameters = DynamicLinkParameters(
      socialMetaTagParameters: SocialMetaTagParameters(
          title: "$name - Prism",
          imageUrl: Uri.parse(thumbUrl),
          description: "Check out this amazing setup I got from Prism."),
      dynamicLinkParametersOptions: DynamicLinkParametersOptions(
          shortDynamicLinkPathLength: ShortDynamicLinkPathLength.short),
      uriPrefix: 'https://prismwallpapers.page.link',
      link: Uri.parse(
          'http://prism.hash.com/setup?index=$index&name=$name&thumbUrl=$thumbUrl'),
      androidParameters: AndroidParameters(
        packageName: 'com.hash.prism',
        minimumVersion: 1,
      ),
      iosParameters: IosParameters(
        bundleId: 'com.hash.prism',
        minimumVersion: '1.0.1',
        appStoreId: '1405860595',
      ));
  final ShortDynamicLink shortDynamicLink = await parameters.buildShortLink();
  final Uri shortUrl = shortDynamicLink.shortUrl;
  Clipboard.setData(ClipboardData(text: shortUrl.toString()));
  Share.share("Hey check this out ➜ $shortUrl");
  analytics.logShare(contentType: 'setupShare', itemId: name, method: 'link');
  logger.d(shortUrl.toString());
}

Future<String> createSharingPrismLink(String userID) async {
  final DynamicLinkParameters parameters = DynamicLinkParameters(
      socialMetaTagParameters: SocialMetaTagParameters(
          title: "Prism",
          imageUrl: Uri.parse(
              "https://raw.githubusercontent.com/Hash-Studios/Prism/master/assets/icon/ios.png"),
          description:
              "Download Prism from my link to get 50 coins instantly!"),
      dynamicLinkParametersOptions: DynamicLinkParametersOptions(
          shortDynamicLinkPathLength: ShortDynamicLinkPathLength.short),
      uriPrefix: 'https://prismwallpapers.page.link',
      link: Uri.parse('http://prism.hash.com/refer?userID=$userID'),
      androidParameters: AndroidParameters(
        packageName: 'com.hash.prism',
        minimumVersion: 1,
      ),
      iosParameters: IosParameters(
        bundleId: 'com.hash.prism',
        minimumVersion: '1.0.1',
        appStoreId: '1405860595',
      ));
  final ShortDynamicLink shortDynamicLink = await parameters.buildShortLink();
  final Uri shortUrl = shortDynamicLink.shortUrl;
  analytics.logShare(contentType: 'prismShare', itemId: userID, method: 'link');
  logger.d(shortUrl.toString());
  return shortUrl.toString();
}

Future<String> createCopyrightLink(bool setup, BuildContext context,
    {String? id,
    String? provider,
    String? url,
    String? thumbUrl,
    String? name,
    String? index}) async {
  Uri shortUrl;
  if (setup == true) {
    final DynamicLinkParameters parameters = DynamicLinkParameters(
        socialMetaTagParameters: SocialMetaTagParameters(
            title: "$name - Prism",
            imageUrl: Uri.parse(thumbUrl!),
            description: "Check out this amazing setup I got from Prism."),
        dynamicLinkParametersOptions: DynamicLinkParametersOptions(
            shortDynamicLinkPathLength: ShortDynamicLinkPathLength.short),
        uriPrefix: 'https://prismwallpapers.page.link',
        link: Uri.parse(
            'http://prism.hash.com/setup?index=$index&name=$name&thumbUrl=$thumbUrl'),
        androidParameters: AndroidParameters(
          packageName: 'com.hash.prism',
          minimumVersion: 1,
        ),
        iosParameters: IosParameters(
          bundleId: 'com.hash.prism',
          minimumVersion: '1.0.1',
          appStoreId: '1405860595',
        ));
    final ShortDynamicLink shortDynamicLink = await parameters.buildShortLink();
    shortUrl = shortDynamicLink.shortUrl;
    analytics.logEvent(name: 'reportSetup');
    logger.d(shortUrl.toString());
  } else {
    final DynamicLinkParameters parameters = DynamicLinkParameters(
        socialMetaTagParameters: SocialMetaTagParameters(
            title: "$id - Prism",
            imageUrl: Uri.parse(thumbUrl!),
            description: "Check out this amazing wallpaper I got from Prism."),
        dynamicLinkParametersOptions: DynamicLinkParametersOptions(
            shortDynamicLinkPathLength: ShortDynamicLinkPathLength.short),
        uriPrefix: 'https://prismwallpapers.page.link',
        link: Uri.parse(
            'http://prism.hash.com/share?id=$id&provider=$provider&url=$url&thumb=$thumbUrl'),
        androidParameters: AndroidParameters(
          packageName: 'com.hash.prism',
          minimumVersion: 1,
        ),
        iosParameters: IosParameters(
          bundleId: 'com.hash.prism',
          minimumVersion: '1.0.1',
          appStoreId: '1405860595',
        ));
    final ShortDynamicLink shortDynamicLink = await parameters.buildShortLink();
    shortUrl = shortDynamicLink.shortUrl;
    analytics.logEvent(name: 'reportWall');
    logger.d(shortUrl.toString());
  }
  showModal(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(),
      builder: (BuildContext context) => CopyrightPopUp(
            setup: setup,
            shortlink: shortUrl.toString(),
          ));
  return "";
}
