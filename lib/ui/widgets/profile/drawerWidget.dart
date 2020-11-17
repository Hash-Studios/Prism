import 'dart:io';

import 'package:Prism/data/profile/wallpaper/getUserProfile.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/config.dart' as config;
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class ProfileDrawer extends StatelessWidget {
  final TextEditingController _twitterController = TextEditingController();
  final TextEditingController _igController = TextEditingController();
  Widget createDrawerHeader(BuildContext context) {
    return DrawerHeader(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        child: Stack(children: <Widget>[
          Positioned(
            top: 12.0,
            left: 16.0,
            child: Container(
              width: MediaQuery.of(context).size.width / 2,
              child: Text(
                main.prefs.get('premium') as bool == true
                    ? "Prism Pro"
                    : "Prism Wallpapers",
                style: Theme.of(context).textTheme.headline3,
              ),
            ),
          ),
          Positioned(
            top: 42.0,
            left: 16.0,
            child: Container(
              width: MediaQuery.of(context).size.width / 2,
              child: Text(
                main.prefs.get('premium') as bool == true
                    ? "Exclusive premium wallpapers & more!"
                    : "Exclusive wallpapers & setups!",
                style: Theme.of(context)
                    .textTheme
                    .bodyText2
                    .copyWith(color: Theme.of(context).accentColor),
              ),
            ),
          ),
        ]));
  }

  Widget createDrawerBodyItem(
      {IconData icon,
      String text,
      GestureTapCallback onTap,
      BuildContext context}) {
    return ListTile(
      leading: Icon(
        icon,
        color: config.Colors().mainAccentColor(1),
      ),
      title: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Container(
          width: MediaQuery.of(context).size.width / 2,
          child: Text(text,
              style: Theme.of(context)
                  .textTheme
                  .caption
                  .copyWith(fontFamily: "Proxima Nova")),
        ),
      ),
      onTap: onTap,
    );
  }

  Widget createDrawerBodyHeader({String text, BuildContext context}) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 0, 0),
      child: Container(
        width: MediaQuery.of(context).size.width / 2,
        child: Text(text,
            style: Theme.of(context).textTheme.headline3.copyWith(
                fontSize: 14,
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
                    onTap: () {},
                    context: context),
            (main.prefs.get('premium') as bool == true)
                ? Container()
                : Divider(),
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
                onTap: () {},
                context: context),
            Divider(),
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
                        Radius.circular(20),
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
                        shape: const StadiumBorder(),
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
                            color: config.Colors().mainAccentColor(1),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FlatButton(
                          shape: const StadiumBorder(),
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
                  ),
                );
              },
              context: context,
            ),
            Divider(),
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
                        Radius.circular(20),
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
                        shape: const StadiumBorder(),
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
                          shape: const StadiumBorder(),
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
                        Radius.circular(20),
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
                        shape: const StadiumBorder(),
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
                          shape: const StadiumBorder(),
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
                  ),
                );
              },
              context: context,
            ),
            Divider(),
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
            Divider(),
            createDrawerBodyHeader(text: "SETTINGS", context: context),
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
            Divider(),
          ],
        ),
      ),
    );
  }
}
