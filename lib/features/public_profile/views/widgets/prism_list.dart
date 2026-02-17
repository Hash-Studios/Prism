import 'dart:io' show Platform;

import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/popup/changelogPopUp.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mailer/flutter_mailer.dart';
import 'package:share_plus/share_plus.dart';

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
                  color: Theme.of(context).colorScheme.secondary,
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
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: const Text(
              "Quick link to pass on to your friends and enemies",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              SharePlus.instance.share(
                ShareParams(
                  text:
                      "Fall in love with Android customisation again! Check out Prism -\nhttps://play.google.com/store/apps/details?id=com.hash.prism",
                  sharePositionOrigin: const Rect.fromLTWH(1, 1, 1, 1),
                ),
              );
            }),
        ListTile(
            leading: const Icon(
              JamIcons.users,
            ),
            title: Text(
              "Privacy Policy",
              style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: const Text(
              "Read Prism's Privacy Policy.",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              launchUrl(Uri.parse("https://github.com/Hash-Studios/Prism/tree/master/PRIVACY.md"));
            }),
        ListTile(
            leading: const Icon(
              JamIcons.picture,
            ),
            title: Text(
              "API",
              style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: const Text(
              "Prism uses Wallhaven and Pexels API for wallpapers",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              showModal(
                context: context,
                builder: (context) => AlertDialog(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(20),
                    ),
                  ),
                  content: SizedBox(
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
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              title: Text(
                                index == 0
                                    ? "WallHaven API"
                                    : index == 1
                                        ? "Pexels API"
                                        : index == 2
                                            ? "Unsplash API"
                                            : "GitHub API",
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              onTap: index == 0
                                  ? () {
                                      HapticFeedback.vibrate();
                                      Navigator.of(context).pop();
                                      launchUrl(Uri.parse("https://wallhaven.cc/help/api"));
                                    }
                                  : index == 1
                                      ? () {
                                          HapticFeedback.vibrate();
                                          Navigator.of(context).pop();
                                          launchUrl(Uri.parse("https://www.pexels.com/api/"));
                                        }
                                      : index == 2
                                          ? () {
                                              HapticFeedback.vibrate();
                                              Navigator.of(context).pop();
                                              launchUrl(Uri.parse("https://unsplash.com/developers"));
                                            }
                                          : () {
                                              HapticFeedback.vibrate();
                                              Navigator.of(context).pop();
                                              launchUrl(Uri.parse("https://developer.github.com/v3/"));
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
                  color: Theme.of(context).colorScheme.secondary,
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
                logger.d('Android $release (SDK $sdkInt), $manufacturer $model');
                final String zipPath = await zipLogs();
                if (zipPath.startsWith(logExportDisabledMarker)) {
                  toasts.error('Log export is temporarily disabled.');
                  return;
                }
                final String encryptedZipPath = zipPath.split("::::").last;
                final String encryptedZipKey = zipPath.split("::::").first;
                final MailOptions mailOptions = MailOptions(
                  body:
                      '----x-x-x----<br>Device info -<br><br>Android version: Android $release<br>SDK Number: SDK $sdkInt<br>Device Manufacturer: $manufacturer<br>Device Model: $model<br>----x-x-x----<br><br>Enter the bug/issue below -<br><br>',
                  subject: '[BUG REPORT::PRISM] - $encryptedZipKey',
                  recipients: ['hash.studios.inc@gmail.com'],
                  isHTML: true,
                  attachments: [
                    encryptedZipPath,
                  ],
                  appSchema: 'com.google.android.gm',
                );
                final MailerResponse response = await FlutterMailer.send(mailOptions);
                if (response != MailerResponse.android) {
                  final MailOptions mailOptions = MailOptions(
                    body:
                        '----x-x-x----<br>Device info -<br><br>Android version: Android $release<br>SDK Number: SDK $sdkInt<br>Device Manufacturer: $manufacturer<br>Device Model: $model<br>----x-x-x----<br><br>Enter the bug/issue below -<br><br>',
                    subject: '[BUG REPORT::PRISM]',
                    recipients: ['hash.studios.inc@gmail.com'],
                    isHTML: true,
                    attachments: [
                      zipPath,
                    ],
                  );
                  await FlutterMailer.send(mailOptions);
                } else {
                  toasts.codeSend("Bug report sent!");
                }
              }
            }),
      ],
    );
  }
}
