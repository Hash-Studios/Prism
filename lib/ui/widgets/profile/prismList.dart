import 'dart:io' show Platform;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/popup/changelogPopUp.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share/share.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/global/globals.dart' as globals;

class PrismList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Prism',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).accentColor,
              ),
            ),
          ),
        ),
        ListTile(
            leading: Icon(
              JamIcons.info,
            ),
            title: new Text(
              "What's new?",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: Text(
              "Check out the changelog",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              showChangelog(context, () {});
            }),
        ListTile(
            leading: Icon(
              JamIcons.star,
            ),
            title: new Text(
              "Rate Prism!",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: Text(
              "If you like Prism, please consider rating it.",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              launch(
                  "https://play.google.com/store/apps/details?id=com.hash.prism");
            }),
        ListTile(
            leading: Icon(
              JamIcons.share_alt,
            ),
            title: new Text(
              "Share Prism!",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: Text(
              "Quick link to pass on to your friends and enemies",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              Share.share(
                  'Hey check out this amazing wallpaper app Prism https://play.google.com/store/apps/details?id=com.hash.prism');
            }),
        ListTile(
            leading: Icon(
              JamIcons.twitter,
            ),
            title: new Text(
              "Follow Prism on Twitter",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: Text(
              "We regularly share setups, wallpapers & organise giveaways.",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              launch("https://twitter.com/PrismWallpapers");
            }),
        ListTile(
            leading: Icon(
              JamIcons.users,
            ),
            title: new Text(
              "Privacy Policy",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: Text(
              "Read Prism's Privacy Policy.",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              launch(
                  "https://github.com/Hash-Studios/Prism/tree/master/PRIVACY.md");
            }),
        ListTile(
            leading: Icon(
              JamIcons.github,
            ),
            title: new Text(
              "View Prism on GitHub!",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: Text(
              "Check out the code or contribute yourself",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () async {
              launch("https://github.com/LiquidatorCoder/Prism");
            }),
        ListTile(
            leading: Icon(
              JamIcons.picture,
            ),
            title: new Text(
              "API",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: Text(
              "Prism uses Wallhaven and Pexels API for wallpapers",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () async {
              showDialog(
                context: context,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(20),
                    ),
                  ),
                  content: Container(
                    height: 280,
                    width: 250,
                    child: Center(
                      child: ListView.builder(
                          itemCount: 4,
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            return ListTile(
                              leading: Icon(
                                index == 0
                                    ? JamIcons.picture
                                    : index == 1
                                        ? JamIcons.camera
                                        : index == 2
                                            ? JamIcons.unsplash
                                            : JamIcons.github,
                                color: Theme.of(context).accentColor,
                              ),
                              title: Text(
                                index == 0
                                    ? "WallHaven API"
                                    : index == 1
                                        ? "Pexels API"
                                        : index == 2
                                            ? "Unsplash API"
                                            : "GitHub API",
                                style: Theme.of(context).textTheme.headline4,
                              ),
                              onTap: index == 0
                                  ? () async {
                                      HapticFeedback.vibrate();
                                      Navigator.of(context).pop();
                                      launch("https://wallhaven.cc/help/api");
                                    }
                                  : index == 1
                                      ? () async {
                                          HapticFeedback.vibrate();
                                          Navigator.of(context).pop();
                                          launch("https://www.pexels.com/api/");
                                        }
                                      : index == 2
                                          ? () async {
                                              HapticFeedback.vibrate();
                                              Navigator.of(context).pop();
                                              launch(
                                                  "https://unsplash.com/developers");
                                            }
                                          : () async {
                                              HapticFeedback.vibrate();
                                              Navigator.of(context).pop();
                                              launch(
                                                  "https://developer.github.com/v3/");
                                            },
                            );
                          }),
                    ),
                  ),
                ),
              );
            }),
        ListTile(
            leading: Icon(
              JamIcons.computer_alt,
            ),
            title: new Text(
              "Version",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: Text(
              "v${globals.currentAppVersion}+${globals.currentAppVersionCode}",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {}),
        ListTile(
            leading: Icon(
              JamIcons.bug,
            ),
            title: new Text(
              "Report a bug",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: Text(
              "Tell us if you found out a bug",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () async {
              if (Platform.isAndroid) {
                var androidInfo = await DeviceInfoPlugin().androidInfo;
                var release = androidInfo.version.release;
                var sdkInt = androidInfo.version.sdkInt;
                var manufacturer = androidInfo.manufacturer;
                var model = androidInfo.model;
                print('Android $release (SDK $sdkInt), $manufacturer $model');
                launch(
                    "mailto:hash.studios.inc@gmail.com?subject=%5BBUG%20REPORT%5D&body=----x-x-x----%0D%0ADevice%20Info%20-%0D%0A%0D%0AAndroid%20Version%3A%20Android%20$release%0D%0ASDK%20Number%3A%20SDK%20$sdkInt%0D%0ADevice%20Manufacturer%3A%20$manufacturer%0D%0ADevice%20Model%3A%20$model%0D%0A----x-x-x----%0D%0A%0D%0AEnter%20the%20bug%2Fissue%20below%20---");
              }
            }),
      ],
    );
  }
}
