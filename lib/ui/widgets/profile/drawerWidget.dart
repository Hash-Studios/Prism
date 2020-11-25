import 'dart:io';

import 'package:Prism/data/profile/wallpaper/getUserProfile.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/config.dart' as config;
import 'package:Prism/main.dart' as main;
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class ProfileDrawer extends StatelessWidget {
  final TextEditingController _twitterController = TextEditingController();
  final TextEditingController _igController = TextEditingController();
  Widget createDrawerHeader(BuildContext context) {
    return Container(
      height: 150,
      child: DrawerHeader(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          child: Stack(children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Container(
                  height: 70,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          main.prefs.get('premium') as bool == true
                              ? "Prism Pro"
                              : "Prism",
                          style: Theme.of(context)
                              .textTheme
                              .headline3
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          main.prefs.get('premium') as bool == true
                              ? "Exclusive premium walls & setups!"
                              : "Exclusive wallpapers & setups!",
                          style: Theme.of(context)
                              .textTheme
                              .bodyText2
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
      {IconData icon,
      String text,
      GestureTapCallback onTap,
      BuildContext context}) {
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
      title: Container(
        width: MediaQuery.of(context).size.width / 2,
        child: Text(
          text,
          style: Theme.of(context).textTheme.caption.copyWith(
              fontFamily: "Proxima Nova", color: Theme.of(context).accentColor),
        ),
      ),
      onTap: onTap,
    );
  }

  Widget createDrawerBodyHeader({String text, BuildContext context}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 0, 0),
      child: Container(
        width: MediaQuery.of(context).size.width / 2,
        child: Text(text,
            style: Theme.of(context).textTheme.headline3.copyWith(
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
            (main.prefs.get('premium') as bool == true)
                ? Container()
                : createDrawerBodyHeader(text: "PREMIUM", context: context),
            (main.prefs.get('premium') as bool == true)
                ? Container()
                : createDrawerBodyItem(
                    icon: JamIcons.coin,
                    text: 'Buy Premium',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, premiumRoute);
                    },
                    context: context),
            (main.prefs.get('premium') as bool == true)
                ? Container()
                : const Divider(),
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
                    content: Container(
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
                            debugPrint(e.toString());
                          }
                          try {
                            dir2.deleteSync(recursive: true);
                            deletedDir2 = true;
                          } catch (e) {
                            debugPrint(e.toString());
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
                          color: config.Colors().mainAccentColor(1),
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
            createDrawerBodyHeader(text: "CONNECTIONS", context: context),
            createDrawerBodyItem(
              icon: JamIcons.twitter,
              text: 'Connect Twitter',
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
                    content: Container(
                      height: 100,
                      width: 250,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              "Enter your Twitter username",
                              style: Theme.of(context).textTheme.headline4,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(500),
                                  color: Theme.of(context).hintColor),
                              child: TextField(
                                cursorColor: config.Colors().mainAccentColor(1),
                                style: Theme.of(context)
                                    .textTheme
                                    .headline5
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                                controller: _twitterController,
                                decoration: InputDecoration(
                                  contentPadding:
                                      const EdgeInsets.only(left: 30, top: 15),
                                  border: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  hintText: "Ex - PrismWallpapers",
                                  hintStyle: Theme.of(context)
                                      .textTheme
                                      .headline5
                                      .copyWith(
                                          fontSize: 14,
                                          color: Theme.of(context).accentColor),
                                  suffixIcon: Icon(
                                    JamIcons.twitter,
                                    color: Theme.of(context).accentColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: <Widget>[
                      FlatButton(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'CANCEL',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: config.Colors().mainAccentColor(1),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FlatButton(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                          color: config.Colors().mainAccentColor(1),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await setUserTwitter(
                                "https://www.twitter.com/${_twitterController.text}",
                                main.prefs.get("id").toString());
                            toasts.codeSend("Successfully linked!");
                          },
                          child: const Text(
                            'SAVE',
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
            createDrawerBodyItem(
              icon: JamIcons.instagram,
              text: 'Connect Instagram',
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
                    content: Container(
                      height: 100,
                      width: 250,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              "Enter your Instagram username",
                              style: Theme.of(context).textTheme.headline4,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(500),
                                  color: Theme.of(context).hintColor),
                              child: TextField(
                                cursorColor: config.Colors().mainAccentColor(1),
                                style: Theme.of(context)
                                    .textTheme
                                    .headline5
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                                controller: _igController,
                                decoration: InputDecoration(
                                  contentPadding:
                                      const EdgeInsets.only(left: 30, top: 15),
                                  border: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  hintText: "Ex - PrismWallpapers",
                                  hintStyle: Theme.of(context)
                                      .textTheme
                                      .headline5
                                      .copyWith(
                                          fontSize: 14,
                                          color: Theme.of(context).accentColor),
                                  suffixIcon: Icon(
                                    JamIcons.instagram,
                                    color: Theme.of(context).accentColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: <Widget>[
                      FlatButton(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'CANCEL',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: config.Colors().mainAccentColor(1),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FlatButton(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                          color: config.Colors().mainAccentColor(1),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await setUserIG(
                                "https://www.instagram.com/${_igController.text}",
                                main.prefs.get("id").toString());
                            toasts.codeSend("Successfully linked!");
                          },
                          child: const Text(
                            'SAVE',
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
            createDrawerBodyHeader(text: "CUSTOMISATION", context: context),
            createDrawerBodyItem(
              icon: JamIcons.wrench,
              text: 'Themes',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, themeViewRoute, arguments: [
                  Provider.of<ThemeModel>(context, listen: false).currentTheme,
                  Color(main.prefs.get("mainAccentColor") as int),
                  Provider.of<ThemeModel>(context, listen: false)
                      .returnThemeIndex(
                    Provider.of<ThemeModel>(context, listen: false)
                        .currentTheme,
                  )
                ]);
              },
              context: context,
            ),
            const Divider(),
            createDrawerBodyHeader(text: "USER", context: context),
            main.prefs.get("name") != null &&
                    main.prefs.get("email") != null &&
                    main.prefs.get("googleimage") != null
                ? createDrawerBodyItem(
                    icon: JamIcons.share_alt,
                    text: 'Share your Profile',
                    context: context,
                    onTap: () {
                      createUserDynamicLink(
                          main.prefs.get("name").toString(),
                          main.prefs.get("email").toString(),
                          main.prefs.get("googleimage").toString(),
                          main.prefs.get("premium") as bool,
                          main.prefs.get("twitter") != ""
                              ? main.prefs
                                  .get("twitter")
                                  .toString()
                                  .split("https://www.twitter.com/")[1]
                              : "",
                          main.prefs.get("instagram") != ""
                              ? main.prefs
                                  .get("instagram")
                                  .toString()
                                  .split("https://www.instagram.com/")[1]
                              : "");
                    })
                : Container(),
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
                PaintingBinding.instance.imageCache.clear();
                await Hive.box('wallpapers').deleteFromDisk();
                await Hive.openBox('wallpapers');
                await Hive.box('collections').deleteFromDisk();
                await Hive.openBox('collections');
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
            Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: createDrawerBodyItem(
                icon: JamIcons.info,
                text: 'About Prism',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, aboutRoute);
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
