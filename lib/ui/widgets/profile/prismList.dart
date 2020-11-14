import 'dart:io' show Platform;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/popup/changelogPopUp.dart';
import 'package:animations/animations.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share/share.dart';
import 'package:url_launcher/url_launcher.dart';

class PrismList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
            leading: const Icon(
              JamIcons.info,
            ),
            title: Text(
              "What's new?",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: const Text(
              "Check out the changelog",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              showChangelog(context, () {});
            }),
        ListTile(
            leading: const Icon(
              JamIcons.share_alt,
            ),
            title: Text(
              "Share Prism!",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: const Text(
              "Quick link to pass on to your friends and enemies",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              // Navigator.pushNamed(context, sharePrismRoute);
              Share.share(
                  "Check out this amazing app called Prism!\nhttps://play.google.com/store/apps/details?id=com.hash.prism");
            }),
        ListTile(
            leading: const Icon(
              JamIcons.users,
            ),
            title: Text(
              "Privacy Policy",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: const Text(
              "Read Prism's Privacy Policy.",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              launch(
                  "https://github.com/Hash-Studios/Prism/tree/master/PRIVACY.md");
            }),
        ListTile(
            leading: const Icon(
              JamIcons.picture,
            ),
            title: Text(
              "API",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: const Text(
              "Prism uses Wallhaven and Pexels API for wallpapers",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () async {
              showModal(
                context: context,
                configuration: const FadeScaleTransitionConfiguration(),
                builder: (context) => AlertDialog(
                  shape: const RoundedRectangleBorder(
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
            leading: const Icon(
              JamIcons.bug,
            ),
            title: Text(
              "Report a bug",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: const Text(
              "Tell us if you found out a bug",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () async {
              if (Platform.isAndroid) {
                final androidInfo = await DeviceInfoPlugin().androidInfo;
                final release = androidInfo.version.release;
                final sdkInt = androidInfo.version.sdkInt;
                final manufacturer = androidInfo.manufacturer;
                final model = androidInfo.model;
                debugPrint(
                    'Android $release (SDK $sdkInt), $manufacturer $model');
                launch(
                    "mailto:hash.studios.inc@gmail.com?subject=%5BBUG%20REPORT%5D&body=----x-x-x----%0D%0ADevice%20Info%20-%0D%0A%0D%0AAndroid%20Version%3A%20Android%20$release%0D%0ASDK%20Number%3A%20SDK%20$sdkInt%0D%0ADevice%20Manufacturer%3A%20$manufacturer%0D%0ADevice%20Model%3A%20$model%0D%0A----x-x-x----%0D%0A%0D%0AEnter%20the%20bug%2Fissue%20below%20---");
              }
            }),
      ],
    );
  }
}
