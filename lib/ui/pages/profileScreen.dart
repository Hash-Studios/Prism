import 'dart:io';

import 'package:Prism/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/signInPopUp.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:share/share.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/globals.dart' as globals;
import 'package:Prism/theme/toasts.dart' as toasts;

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(slivers: <Widget>[
        SliverAppBar(
          backgroundColor: main.prefs.getBool("isLoggedin")
              ? Theme.of(context).primaryColor
              : Color(0xFFE57697),
          automaticallyImplyLeading: false,
          pinned: false,
          floating: true,
          snap: true,
          expandedHeight: 200.0,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                main.prefs.getBool("isLoggedin")
                    ? Container(
                        child: Image.asset(
                        "assets/images/bg4.jpg",
                        fit: BoxFit.cover,
                      ))
                    : Container(
                        child: Image.asset(
                        "assets/images/bgp.png",
                        fit: BoxFit.cover,
                      )),
                main.prefs.getBool("isLoggedin")
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          main.prefs.getString("googleimage") == null
                              ? Container()
                              : CircleAvatar(
                                  radius: 60,
                                  backgroundImage: NetworkImage(
                                      main.prefs.getString("googleimage")),
                                ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: main.prefs.getString("name") == null
                                    ? Container()
                                    : Text(
                                        main.prefs.getString("name"),
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                              ),
                              main.prefs.getString("email") == null
                                  ? Container()
                                  : Text(
                                      main.prefs.getString("email"),
                                      style: TextStyle(fontSize: 14),
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
            delegate: SliverChildListDelegate.fixed([
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
          ListTile(
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
              onTap: () {
                final dir = Directory("storage/emulated/0/Prism/");
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
              }),
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
            leading: Icon(JamIcons.lightbulb),
            title: Text(
              "Dark Mode",
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
              // ListTile(
              //     leading: Icon(
              //       Icons.data_usage,
              //     ),
              //     title: Text(
              //       "Clear Cache",
              //       style: TextStyle(
              //           color: Theme.of(context).accentColor,
              //           fontWeight: FontWeight.w500,
              //           fontFamily: "Proxima Nova"),
              //     ),
              //     subtitle: Text(
              //       "Clear locally cached images",
              //       style: TextStyle(fontSize: 12),
              //     ),
              //     onTap: () {
              // DefaultCacheManager().emptyCache();
              // Fluttertoast.showToast(
              //     msg: "Cleared cache!",
              //     toastLength: Toast.LENGTH_LONG,
              //     timeInSecForIosWeb: 1,
              //     textColor: Colors.white,
              //     fontSize: 16.0);
              // }),
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
          main.prefs.getBool("isLoggedin")
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'User',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).accentColor,
                    ),
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
                          "Clear Favorites",
                          style: TextStyle(
                              color: Theme.of(context).accentColor,
                              fontWeight: FontWeight.w500,
                              fontFamily: "Proxima Nova"),
                        ),
                        subtitle: Text(
                          "Remove all favorites",
                          style: TextStyle(fontSize: 12),
                        ),
                        onTap: () {
                          // Fluttertoast.showToast(
                          //     msg: "Cleared all favorites!",
                          //     toastLength: Toast.LENGTH_LONG,
                          //     timeInSecForIosWeb: 1,
                          //     textColor: Colors.white,
                          //     fontSize: 16.0);
                          // deleteData();
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
                    "About",
                    style: TextStyle(
                        color: Theme.of(context).accentColor,
                        fontWeight: FontWeight.w500,
                        fontFamily: "Proxima Nova"),
                  ),
                  subtitle: Text(
                    "Know more about Prism",
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Dialog signinPopUp = Dialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: SingleChildScrollView(
                        child: Container(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Theme.of(context).primaryColor),
                          width: MediaQuery.of(context).size.width * .71,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                height: 150,
                                width: MediaQuery.of(context).size.width * .71,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        topRight: Radius.circular(20)),
                                    color: Theme.of(context).hintColor),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 20),
                                  child: Image.asset(
                                    'assets/images/appIcon.png',
                                    fit: BoxFit.scaleDown,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(20, 12, 0, 4),
                                    child: Text(
                                      'v2.0.0',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: Theme.of(context).accentColor),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: 20,
                              ),
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(left: 20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Icon(
                                            JamIcons.phone,
                                            size: 22,
                                            color: Color(0xFFE57697),
                                          ),
                                          SizedBox(height: 10),
                                          Icon(
                                            JamIcons.camera,
                                            size: 22,
                                            color: Color(0xFFE57697),
                                          ),
                                          SizedBox(height: 10),
                                          Icon(
                                            JamIcons.search,
                                            size: 22,
                                            color: Color(0xFFE57697),
                                          ),
                                          SizedBox(height: 10),
                                          Icon(
                                            JamIcons.brush,
                                            size: 22,
                                            color: Color(0xFFE57697),
                                          ),
                                          SizedBox(height: 10),
                                          Icon(
                                            JamIcons.pictures,
                                            size: 22,
                                            color: Color(0xFFE57697),
                                          ),
                                          SizedBox(height: 10),
                                          Icon(
                                            JamIcons.google,
                                            size: 22,
                                            color: Color(0xFFE57697),
                                          ),
                                          SizedBox(height: 10),
                                          Icon(
                                            JamIcons.settings_alt,
                                            size: 22,
                                            color: Color(0xFFE57697),
                                          ),
                                          SizedBox(height: 10),
                                          Icon(
                                            JamIcons.eyedropper,
                                            size: 22,
                                            color: Color(0xFFE57697),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(right: 20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Text(
                                            "Completely new redesigned UI.",
                                            style: Theme.of(context)
                                                .textTheme
                                                .headline5
                                                .copyWith(
                                                    color: Theme.of(context)
                                                        .accentColor),
                                          ),
                                          SizedBox(height: 13),
                                          Text(
                                            "Added Pexels API support.",
                                            style: Theme.of(context)
                                                .textTheme
                                                .headline5
                                                .copyWith(
                                                    color: Theme.of(context)
                                                        .accentColor),
                                          ),
                                          SizedBox(height: 13),
                                          Text(
                                            "Added new color search.",
                                            style: Theme.of(context)
                                                .textTheme
                                                .headline5
                                                .copyWith(
                                                    color: Theme.of(context)
                                                        .accentColor),
                                          ),
                                          SizedBox(height: 13),
                                          Text(
                                            "Added new themes.",
                                            style: Theme.of(context)
                                                .textTheme
                                                .headline5
                                                .copyWith(
                                                    color: Theme.of(context)
                                                        .accentColor),
                                          ),
                                          SizedBox(height: 13),
                                          Text(
                                            "Added 1M+ wallpapers.",
                                            style: Theme.of(context)
                                                .textTheme
                                                .headline5
                                                .copyWith(
                                                    color: Theme.of(context)
                                                        .accentColor),
                                          ),
                                          SizedBox(height: 13),
                                          Text(
                                            "Added non intrusive sign in support.",
                                            style: Theme.of(context)
                                                .textTheme
                                                .headline5
                                                .copyWith(
                                                    color: Theme.of(context)
                                                        .accentColor),
                                          ),
                                          SizedBox(height: 13),
                                          Text(
                                            "Added new quick wallpaper actions.",
                                            style: Theme.of(context)
                                                .textTheme
                                                .headline5
                                                .copyWith(
                                                    color: Theme.of(context)
                                                        .accentColor),
                                          ),
                                          SizedBox(height: 13),
                                          Text(
                                            "Added new palette generator.",
                                            style: Theme.of(context)
                                                .textTheme
                                                .headline5
                                                .copyWith(
                                                    color: Theme.of(context)
                                                        .accentColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ]),
                              SizedBox(
                                height: 25,
                              ),
                              FlatButton(
                                shape: StadiumBorder(),
                                color: Color(0xFFE57697),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text(
                                  'CLOSE',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 15,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    showDialog(
                        context: context,
                        builder: (BuildContext context) => signinPopUp);
                  }),
              ListTile(
                  leading: Icon(
                    JamIcons.share,
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
              // ListTile(
              //     leading: Icon(
              //       Icons.wallpaper,
              //     ),
              //     title: new Text(
              //       "API",
              //       style: TextStyle(
              //           color: Theme.of(context).accentColor,
              //           fontWeight: FontWeight.w500,
              //           fontFamily: "Proxima Nova"),
              //     ),
              //     subtitle: Text(
              //       "Prism uses Wallhaven API for wallpapers",
              //       style: TextStyle(fontSize: 12),
              //     ),
              //     onTap: () async {
              //       launch("https://wallhaven.cc/help/api");
              //     }),
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
                    "2.0 stable",
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {}),
              ListTile(
                  leading: Icon(
                    JamIcons.coffee,
                  ),
                  title: new Text(
                    "Buy us a cup of tea",
                    style: TextStyle(
                        color: Theme.of(context).accentColor,
                        fontWeight: FontWeight.w500,
                        fontFamily: "Proxima Nova"),
                  ),
                  subtitle: Text(
                    "Support us if you like what we do",
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    launch("https://buymeacoff.ee/HashStudios");
                  }),
              ExpansionTile(
                leading: Icon(
                  JamIcons.users,
                ),
                title: new Text(
                  "Developers",
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
                ],
              ),
            ],
          ),
        ]))
      ]),
    );
  }
}
