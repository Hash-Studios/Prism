import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share/share.dart';

class ShareButton extends StatefulWidget {
  final String id;
  final String provider;
  final String url;
  final String thumbUrl;
  const ShareButton({
    @required this.id,
    @required this.provider,
    @required this.url,
    @required this.thumbUrl,
    Key key,
  }) : super(key: key);

  @override
  _ShareButtonState createState() => _ShareButtonState();
}

class _ShareButtonState extends State<ShareButton> {
  bool isLoading;
  @override
  void initState() {
    isLoading = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        debugPrint("Share");
        onShare();
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(.25),
                    blurRadius: 4,
                    offset: const Offset(0, 4))
              ],
              borderRadius: BorderRadius.circular(500),
            ),
            padding: const EdgeInsets.all(17),
            child: Icon(
              JamIcons.share_alt,
              color: Theme.of(context).accentColor,
              size: 20,
            ),
          ),
          Positioned(
              top: 0,
              left: 0,
              height: 53,
              width: 53,
              child:
                  isLoading ? const CircularProgressIndicator() : Container())
        ],
      ),
    );
  }

  Future<void> onShare() async {
    setState(() {
      isLoading = true;
    });
    final DynamicLinkParameters parameters = DynamicLinkParameters(
        socialMetaTagParameters: SocialMetaTagParameters(
            title: "Prism Wallpapers - ${widget.id}",
            imageUrl: Uri.parse(widget.thumbUrl),
            description:
                "Check out this amazing wallpaper I got, from Prism Wallpapers App."),
        dynamicLinkParametersOptions: DynamicLinkParametersOptions(
            shortDynamicLinkPathLength: ShortDynamicLinkPathLength.short),
        uriPrefix: 'https://prismwallpapers.page.link',
        link: Uri.parse(
            'http://prism.hash.com/share?id=${widget.id}&provider=${widget.provider}&url=${widget.url}&thumb=${widget.thumbUrl}'),
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
    Share.share("🔥Check this out ➜ $shortUrl");
    debugPrint(shortUrl.toString());
    analytics.logShare(
        contentType: 'wallpaperScreen', itemId: widget.id, method: 'link');
    setState(() {
      isLoading = false;
    });
  }
}
