import 'dart:io';

import 'package:Prism/data/notifications/model/inAppNotifModel.dart';
// import 'package:Prism/data/setups/provider/setupProvider.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/ui/widgets/popup/enterCodePanel.dart';
import 'package:animations/animations.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_mailer/flutter_mailer.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileDrawer extends StatelessWidget {
  Widget createDrawerHeader(BuildContext context) {
    return SizedBox(
      height: 150,
      child: DrawerHeader(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          child: Stack(children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: SizedBox(
                  height: 70,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          globals.prismUser.premium == true
                              ? "Prism Pro"
                              : "Prism",
                          style: Theme.of(context)
                              .textTheme
                              .headline3!
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          globals.prismUser.premium == true
                              ? "Exclusive premium walls & setups!"
                              : "Exclusive wallpapers & setups!",
                          style: Theme.of(context)
                              .textTheme
                              .bodyText2!
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ])),
    );
  }

  Widget createDrawerBodyItem(
      {IconData? icon,
      required String text,
      GestureTapCallback? onTap,
      required BuildContext context}) {
    return ListTile(
      dense: true,
      trailing: Icon(
        JamIcons.chevron_right,
        color: Theme.of(context).accentColor,
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      leading: Icon(
        icon,
        color: Theme.of(context).accentColor,
      ),
      title: SizedBox(
        width: MediaQuery.of(context).size.width / 2,
        child: Text(
          text,
          style: Theme.of(context).textTheme.caption!.copyWith(
              fontFamily: "Proxima Nova", color: Theme.of(context).accentColor),
        ),
      ),
      onTap: onTap,
    );
  }

  Widget createDrawerBodyHeader(
      {required String text, required BuildContext context}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 0, 0),
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 2,
        child: Text(text,
            style: Theme.of(context).textTheme.headline3!.copyWith(
                fontSize: 12,
                color: Theme.of(context).accentColor.withOpacity(0.4))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Theme.of(context).primaryColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            createDrawerHeader(context),
            if (globals.prismUser.premium == true)
              Container()
            else
              createDrawerBodyHeader(text: "PREMIUM", context: context),
            if (globals.prismUser.premium == true)
              Container()
            else
              createDrawerBodyItem(
                  icon: JamIcons.coin,
                  text: 'Buy Premium',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, premiumRoute);
                  },
                  context: context),
            if (globals.prismUser.premium == true)
              Container()
            else
              const Divider(),
            createDrawerBodyHeader(text: "FAVOURITES", context: context),
            createDrawerBodyItem(
                icon: JamIcons.picture,
                text: 'Wallpapers',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, favWallRoute);
                },
                context: context),
            createDrawerBodyItem(
                icon: JamIcons.instant_picture,
                text: 'Setups',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, favSetupRoute);
                },
                context: context),
            // createDrawerBodyItem(
            //     icon: JamIcons.ghost,
            //     text: 'Get Icons from setups',
            //     onTap: () async {
            //       final List iconLinks =
            //           await Provider.of<SetupProvider>(context, listen: false)
            //               .getAllSetups();
            //       logger.d(iconLinks);
            //       showModalBottomSheet(
            //         context: context,
            //         builder: (context) => Container(
            //           child: ListView.builder(
            //             itemCount: iconLinks.length,
            //             itemBuilder: (context, index) => Text(
            //               iconLinks[index].toString(),
            //             ),
            //           ),
            //         ),
            //       );
            //     },
            //     context: context),
            const Divider(),
            createDrawerBodyHeader(text: "DOWNLOADS", context: context),
            createDrawerBodyItem(
              icon: JamIcons.download,
              text: 'Downloaded Walls',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, downloadRoute);
              },
              context: context,
            ),
            createDrawerBodyItem(
              icon: JamIcons.trash_alt,
              text: 'Clear all Downloads',
              onTap: () async {
                Navigator.pop(context);
                showModal(
                  context: context,
                  configuration: const FadeScaleTransitionConfiguration(),
                  builder: (context) => AlertDialog(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(10),
                      ),
                    ),
                    content: SizedBox(
                      height: 50,
                      width: 250,
                      child: Center(
                        child: Text(
                          "Do you want remove all your downloads?",
                          style: Theme.of(context).textTheme.headline4,
                        ),
                      ),
                    ),
                    actions: <Widget>[
                      FlatButton(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          final dir = Directory("storage/emulated/0/Prism/");
                          final dir2 =
                              Directory("storage/emulated/0/Pictures/Prism/");
                          final status = await Permission.storage.status;
                          if (!status.isGranted) {
                            await Permission.storage.request();
                          }
                          bool deletedDir = false;
                          bool deletedDir2 = false;
                          try {
                            dir.deleteSync(recursive: true);
                            deletedDir = true;
                          } catch (e) {
                            logger.d(e.toString());
                          }
                          try {
                            dir2.deleteSync(recursive: true);
                            deletedDir2 = true;
                          } catch (e) {
                            logger.d(e.toString());
                          }
                          if (deletedDir || deletedDir2) {
                            Fluttertoast.showToast(
                              msg: "Deleted all downloads!",
                              toastLength: Toast.LENGTH_LONG,
                              textColor: Colors.white,
                              backgroundColor: Colors.green[400],
                            );
                          } else {
                            Fluttertoast.showToast(
                              msg: "No downloads!",
                              toastLength: Toast.LENGTH_LONG,
                              textColor: Colors.white,
                              backgroundColor: Colors.red[400],
                            );
                          }
                        },
                        child: Text(
                          'YES',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: Theme.of(context).accentColor,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FlatButton(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                          color: Theme.of(context).errorColor,
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'NO',
                            style: TextStyle(
                              fontSize: 16.0,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                );
              },
              context: context,
            ),
            const Divider(),
            createDrawerBodyHeader(text: "REVIEWS", context: context),
            createDrawerBodyItem(
              icon: JamIcons.check,
              text: 'Review Status',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, reviewRoute);
              },
              context: context,
            ),
            const Divider(),
            createDrawerBodyHeader(text: "CUSTOMISATION", context: context),
            createDrawerBodyItem(
              icon: JamIcons.wrench,
              text: 'Themes',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  themeViewRoute,
                );
              },
              context: context,
            ),
            const Divider(),
            createDrawerBodyHeader(text: "USER", context: context),
            createDrawerBodyItem(
                icon: JamIcons.share_alt,
                text: 'Share your Profile',
                context: context,
                onTap: () {
                  createUserDynamicLink(
                    globals.prismUser.name.toString(),
                    globals.prismUser.username.toString(),
                    globals.prismUser.email.toString(),
                    globals.prismUser.bio.toString(),
                    globals.prismUser.profilePhoto.toString(),
                  );
                }),
            createDrawerBodyItem(
              icon: JamIcons.log_out,
              text: 'Log out',
              onTap: () {
                Navigator.pop(context);
                globals.gAuth.signOutGoogle();
                toasts.codeSend("Log out Successful!");
                main.RestartWidget.restartApp(context);
              },
              context: context,
            ),
            const Divider(),
            createDrawerBodyHeader(text: "SETTINGS", context: context),
            createDrawerBodyItem(
              icon: JamIcons.pie_chart_alt,
              text: 'Clear cache',
              onTap: () async {
                Navigator.pop(context);
                DefaultCacheManager().emptyCache();
                PaintingBinding.instance!.imageCache!.clear();
                await Hive.box<InAppNotif>('inAppNotifs').deleteFromDisk();
                await Hive.openBox<InAppNotif>('inAppNotifs');
                main.prefs.delete('lastFetchTime');
                await Hive.box('setups').deleteFromDisk();
                await Hive.openBox('setups');
                toasts.codeSend("Cleared cache!");
              },
              context: context,
            ),
            createDrawerBodyItem(
              icon: JamIcons.cog,
              text: 'Settings',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, settingsRoute);
              },
              context: context,
            ),
            createDrawerBodyItem(
              icon: JamIcons.info,
              text: 'About Prism',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, aboutRoute);
              },
              context: context,
            ),
            const Divider(),
            createDrawerBodyHeader(text: "MORE", context: context),
            createDrawerBodyItem(
                icon: JamIcons.bug,
                text: 'Report a bug',
                context: context,
                onTap: () async {
                  if (Platform.isAndroid) {
                    final androidInfo = await DeviceInfoPlugin().androidInfo;
                    final release = androidInfo.version.release;
                    final sdkInt = androidInfo.version.sdkInt;
                    final manufacturer = androidInfo.manufacturer;
                    final model = androidInfo.model;
                    logger.d(
                        'Android $release (SDK $sdkInt), $manufacturer $model');
                    final String zipPath = await zipLogs();
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
                    final MailerResponse response =
                        await FlutterMailer.send(mailOptions);
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
            Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: createDrawerBodyItem(
                icon: JamIcons.coin,
                text: 'Enter Code',
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    isScrollControlled: true,
                    context: context,
                    builder: (context) => const EnterCodePanel(),
                  );
                },
                context: context,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
