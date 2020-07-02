import 'dart:io';

import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/popup/changelogPopUp.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share/share.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int favCount;
  @override
  void initState() {
    checkFav();
    super.initState();
  }

  Future<bool> onWillPop() async {
    String route = currentRoute;
    currentRoute = previousRoute;
    previousRoute = route;
    print(currentRoute);
    return true;
  }

  Future checkFav() async {
    if (main.prefs.getBool("isLoggedin")) {
      await Provider.of<FavouriteProvider>(context, listen: false)
          .countFav()
          .then((value) {
        print(value);
        setState(() {
          favCount = value;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        body: CustomScrollView(slivers: <Widget>[
          SliverAppBar(
            backgroundColor: Color(0xFFE57697),
            leading: IconButton(
                icon: Icon(
                  JamIcons.chevron_left,
                  color: Colors.white,
                ),
                onPressed: () {
                  String route = currentRoute;
                  currentRoute = previousRoute;
                  previousRoute = route;
                  print(currentRoute);
                  Navigator.pop(context);
                }),
            pinned: true,
            expandedHeight: 280.0,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  main.prefs.getBool("isLoggedin")
                      ? Container(
                          color: Color(0xFFE57697),
                        )
                      : Container(
                          child: SvgPicture.asset(
                            "assets/images/BG Banner Light.svg",
                            fit: BoxFit.cover,
                          ),
                        ),
                  main.prefs.getBool("isLoggedin")
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                main.prefs.getString("googleimage") == null
                                    ? Container()
                                    : Container(
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(5000),
                                            boxShadow: [
                                              BoxShadow(
                                                  blurRadius: 16,
                                                  offset: Offset(0, 4),
                                                  color: Color(0xFF000000)
                                                      .withOpacity(0.24))
                                            ]),
                                        child: CircleAvatar(
                                          radius: 50,
                                          backgroundImage: NetworkImage(main
                                              .prefs
                                              .getString("googleimage")),
                                        ),
                                      ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(8, 15, 8, 6),
                                  child: main.prefs.getString("name") == null
                                      ? Container()
                                      : Text(
                                          main.prefs.getString("name"),
                                          style: TextStyle(
                                              fontFamily: "Proxima Nova",
                                              color: Colors.white,
                                              fontSize: 32,
                                              fontWeight: FontWeight.w700),
                                        ),
                                ),
                                main.prefs.getString("email") == null
                                    ? Container()
                                    : Text(
                                        main.prefs.getString("email"),
                                        style: TextStyle(
                                            fontFamily: "Proxima Nova",
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500),
                                      ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: RichText(
                                    text: TextSpan(
                                        text: favCount.toString(),
                                        style: TextStyle(
                                            fontFamily: "Proxima Nova",
                                            fontSize: 24,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w700),
                                        children: [
                                          TextSpan(
                                            text: " Favourites",
                                            style: TextStyle(
                                                fontFamily: "Proxima Nova",
                                                color: Colors.white70,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w500),
                                          )
                                        ]),

                                    // style: TextStyle(
                                    //     fontFamily: "Proxima Nova",
                                    //     fontSize: 24,
                                    //     fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            )
                          ],
                        )
                      : Container(),
                ],
              ),
            ),
          ),
          SliverList(
              delegate: SliverChildListDelegate([
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Downloads',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).accentColor,
                ),
              ),
            ),
            ListTile(
              onTap: () {
                if (!main.prefs.getBool("isLoggedin")) {
                  googleSignInPopUp(context, () {
                    Navigator.pushNamed(context, DownloadRoute);
                  });
                } else {
                  Navigator.pushNamed(context, DownloadRoute);
                }
              },
              leading: Icon(JamIcons.download),
              title: Text(
                "My Downloads",
                style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Proxima Nova"),
              ),
              subtitle: Text(
                "See all your downloaded wallpapers",
                style: TextStyle(fontSize: 12),
              ),
              trailing: Icon(JamIcons.chevron_right),
            ),
            main.prefs.getBool("isLoggedin")
                ? ListTile(
                    leading: Icon(
                      JamIcons.database,
                    ),
                    title: new Text(
                      "Clear Downloads",
                      style: TextStyle(
                          color: Theme.of(context).accentColor,
                          fontWeight: FontWeight.w500,
                          fontFamily: "Proxima Nova"),
                    ),
                    subtitle: Text(
                      "Clear downloaded wallpapers",
                      style: TextStyle(fontSize: 12),
                    ),
                    onTap: () async {
                      final dir = Directory("storage/emulated/0/Prism/");
                      var status = await Permission.storage.status;
                      if (!status.isGranted) {
                        await Permission.storage.request();
                      }
                      try {
                        dir.deleteSync(recursive: true);
                        Fluttertoast.showToast(
                            msg: "Deleted all downloads!",
                            toastLength: Toast.LENGTH_LONG,
                            timeInSecForIosWeb: 1,
                            textColor: Colors.white,
                            backgroundColor: Colors.green[400],
                            fontSize: 16.0);
                      } catch (e) {
                        Fluttertoast.showToast(
                            msg: "No downloads!",
                            toastLength: Toast.LENGTH_LONG,
                            timeInSecForIosWeb: 1,
                            textColor: Colors.white,
                            backgroundColor: Colors.red[400],
                            fontSize: 16.0);
                      }
                    })
                : Container(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Personalisation',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).accentColor,
                ),
              ),
            ),
            ListTile(
              onTap: () {
                Provider.of<ThemeModel>(context, listen: false).toggleTheme();
                main.RestartWidget.restartApp(context);
              },
              leading: main.prefs.getBool("darkMode") == null
                  ? Icon(JamIcons.moon_f)
                  : main.prefs.getBool("darkMode")
                      ? Icon(JamIcons.sun_f)
                      : Icon(JamIcons.moon_f),
              title: Text(
                main.prefs.getBool("darkMode") == null
                    ? "Dark Mode"
                    : main.prefs.getBool("darkMode")
                        ? "Light Mode"
                        : "Dark Mode",
                style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Proxima Nova"),
              ),
              subtitle: Text(
                "Toggle app theme",
                style: TextStyle(fontSize: 12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'General',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).accentColor,
                ),
              ),
            ),
            Column(
              children: [
                ListTile(
                    leading: Icon(
                      JamIcons.pie_chart_alt,
                    ),
                    title: Text(
                      "Clear Cache",
                      style: TextStyle(
                          color: Theme.of(context).accentColor,
                          fontWeight: FontWeight.w500,
                          fontFamily: "Proxima Nova"),
                    ),
                    subtitle: Text(
                      "Clear locally cached images",
                      style: TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      DefaultCacheManager().emptyCache();
                      toasts.clearCache();
                    }),
                ListTile(
                  onTap: () {
                    main.RestartWidget.restartApp(context);
                  },
                  leading: Icon(JamIcons.refresh),
                  title: Text(
                    "Restart App",
                    style: TextStyle(
                        color: Theme.of(context).accentColor,
                        fontWeight: FontWeight.w500,
                        fontFamily: "Proxima Nova"),
                  ),
                  subtitle: Text(
                    "Force the application to restart",
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'User',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).accentColor,
                ),
              ),
            ),
            main.prefs.getBool("isLoggedin") == false
                ? ListTile(
                    onTap: () {
                      if (!main.prefs.getBool("isLoggedin")) {
                        googleSignInPopUp(context, () {
                          main.RestartWidget.restartApp(context);
                        });
                      } else {
                        main.RestartWidget.restartApp(context);
                      }
                    },
                    leading: Icon(JamIcons.log_in),
                    title: Text(
                      "Log in",
                      style: TextStyle(
                          color: Theme.of(context).accentColor,
                          fontWeight: FontWeight.w500,
                          fontFamily: "Proxima Nova"),
                    ),
                    subtitle: Text(
                      "Log in to sync data across devices",
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                : Container(),
            main.prefs.getBool("isLoggedin")
                ? Column(
                    children: [
                      ListTile(
                          leading: Icon(
                            JamIcons.heart,
                          ),
                          title: new Text(
                            "Clear favourites",
                            style: TextStyle(
                                color: Theme.of(context).accentColor,
                                fontWeight: FontWeight.w500,
                                fontFamily: "Proxima Nova"),
                          ),
                          subtitle: Text(
                            "Remove all favourites",
                            style: TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            toasts.clearFav();
                            Provider.of<FavouriteProvider>(context,
                                    listen: false)
                                .deleteData();
                          }),
                      ListTile(
                          leading: Icon(
                            JamIcons.log_out,
                          ),
                          title: new Text(
                            "Logout",
                            style: TextStyle(
                                color: Theme.of(context).accentColor,
                                fontWeight: FontWeight.w500,
                                fontFamily: "Proxima Nova"),
                          ),
                          subtitle: Text(
                            "Sign out from your account",
                            style: TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            globals.gAuth.signOutGoogle();
                            toasts.successLogOut();
                            main.RestartWidget.restartApp(context);
                          }),
                    ],
                  )
                : Container(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Prism',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).accentColor,
                ),
              ),
            ),
            Column(
              children: [
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
                            height: 150,
                            width: 250,
                            child: Center(
                              child: ListView.builder(
                                  itemCount: 2,
                                  shrinkWrap: true,
                                  itemBuilder: (context, index) {
                                    return ListTile(
                                      leading: Icon(
                                        index == 0
                                            ? JamIcons.picture
                                            : JamIcons.camera,
                                        color: Theme.of(context).accentColor,
                                      ),
                                      title: Text(
                                        index == 0
                                            ? "WallHaven API"
                                            : "Pexels API",
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline4,
                                      ),
                                      onTap: index == 0
                                          ? () async {
                                              HapticFeedback.vibrate();
                                              Navigator.of(context).pop();
                                              launch(
                                                  "https://wallhaven.cc/help/api");
                                            }
                                          : () async {
                                              HapticFeedback.vibrate();
                                              Navigator.of(context).pop();
                                              launch(
                                                  "https://www.pexels.com/api/");
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
                      "v2.3.5+1",
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
                    onTap: () {
                      launch("https://github.com/Hash-Studios/Prism/issues");
                    }),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Hash Studios',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).accentColor,
                ),
              ),
            ),
            Column(children: [
              ListTile(
                  leading: Icon(
                    JamIcons.luggage,
                  ),
                  title: new Text(
                    "Wanna work with us?",
                    style: TextStyle(
                        color: Theme.of(context).accentColor,
                        fontWeight: FontWeight.w500,
                        fontFamily: "Proxima Nova"),
                  ),
                  subtitle: Text(
                    "We are recruiting Flutter developers",
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    launch("https://forms.gle/nSt4QtiQVVaZvhdA8");
                  }),
              // ListTile(
              //     leading: Icon(
              //       JamIcons.coffee,
              //     ),
              //     title: new Text(
              //       "Buy us a cup of tea",
              //       style: TextStyle(
              //           color: Theme.of(context).accentColor,
              //           fontWeight: FontWeight.w500,
              //           fontFamily: "Proxima Nova"),
              //     ),
              //     subtitle: Text(
              //       "Support us if you like what we do",
              //       style: TextStyle(fontSize: 12),
              //     ),
              //     onTap: () {
              //       launch("https://buymeacoff.ee/HashStudios");
              //     }),
              ExpansionTile(
                leading: Icon(
                  JamIcons.users,
                ),
                title: new Text(
                  "Meet the awesome team",
                  style: TextStyle(
                      color: Theme.of(context).accentColor,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova"),
                ),
                subtitle: Text(
                  "Check out the cool devs!",
                  style: TextStyle(fontSize: 12),
                ),
                children: [
                  ListTile(
                      leading: CircleAvatar(
                        backgroundImage: AssetImage("assets/images/AB.jpg"),
                      ),
                      title: new Text(
                        "LiquidatorCoder",
                        style: TextStyle(
                            color: Theme.of(context).accentColor,
                            fontWeight: FontWeight.w500,
                            fontFamily: "Proxima Nova"),
                      ),
                      subtitle: Text(
                        "Abhay Maurya",
                        style: TextStyle(fontSize: 12),
                      ),
                      onTap: () async {
                        launch("https://github.com/LiquidatorCoder");
                      }),
                  ListTile(
                      leading: CircleAvatar(
                        backgroundImage: AssetImage("assets/images/AK.jpg"),
                      ),
                      title: new Text(
                        "CodeNameAkshay",
                        style: TextStyle(
                            color: Theme.of(context).accentColor,
                            fontWeight: FontWeight.w500,
                            fontFamily: "Proxima Nova"),
                      ),
                      subtitle: Text(
                        "Akshay Maurya",
                        style: TextStyle(fontSize: 12),
                      ),
                      onTap: () async {
                        launch("https://github.com/codenameakshay");
                      }),
                  ListTile(
                      leading: CircleAvatar(
                        backgroundImage: AssetImage("assets/images/PT.jpg"),
                      ),
                      title: new Text(
                        "1-2-ka-4-4-2-ka-1",
                        style: TextStyle(
                            color: Theme.of(context).accentColor,
                            fontWeight: FontWeight.w500,
                            fontFamily: "Proxima Nova"),
                      ),
                      subtitle: Text(
                        "Pratyush Tiwari",
                        style: TextStyle(fontSize: 12),
                      ),
                      onTap: () async {
                        launch("https://github.com/1-2-ka-4-4-2-ka-1");
                      }),
                ],
              ),
            ])
          ]))
        ]),
      ),
    );
  }
}
