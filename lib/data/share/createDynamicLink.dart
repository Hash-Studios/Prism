import 'package:Prism/analytics/analytics_service.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/services.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

void createDynamicLink(
    String id, String provider, String url, String thumbUrl) async {
  final DynamicLinkParameters parameters = DynamicLinkParameters(
      socialMetaTagParameters: SocialMetaTagParameters(
          title: "Prism Wallpapers - $id",
          imageUrl: Uri.parse(thumbUrl),
          description:
              "Check out this amazing wallpaper I got, from Prism Wallpapers App."),
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
      ClipboardData(text: "🔥Check this out ➜ " + shortUrl.toString()));
  analytics.logShare(contentType: 'focussedMenu', itemId: id, method: 'link');
  toasts.codeSend("Sharing link copied!");
  print(shortUrl);
}
