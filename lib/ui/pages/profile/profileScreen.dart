import 'dart:async';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/data/profile/wallpaper/profileWallProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';

import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/pages/profile/downloadList.dart';
import 'package:Prism/ui/pages/profile/prismList.dart';
import 'package:Prism/ui/pages/profile/studioList.dart';
import 'package:Prism/ui/widgets/home/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/inheritedScrollControllerProvider.dart';
import 'package:Prism/ui/widgets/profile/profileLoader.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:provider/provider.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: BottomBar(child: ProfileChild()));
  }
}

class ProfileChild extends StatefulWidget {
  @override
  _ProfileChildState createState() => _ProfileChildState();
}

class _ProfileChildState extends State<ProfileChild> {
  int favCount;
  int profileCount;
  @override
  void initState() {
    checkFav();
    super.initState();
  }

  Future<bool> onWillPop() async {
    navStack.removeLast();
    print(navStack);
    return true;
  }

  Future checkFav() async {
    if (main.prefs.getBool("isLoggedin")) {
      await Provider.of<FavouriteProvider>(context, listen: false)
          .countFav()
          .then(
        (value) {
          print(value);
          setState(
            () {
              favCount = value;
            },
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController controller =
        InheritedDataProvider.of(context).scrollController;
    return WillPopScope(
        onWillPop: onWillPop,
        child: main.prefs.getBool("isLoggedin")
            ? DefaultTabController(
                length: 2,
                child: Scaffold(
                  backgroundColor: Theme.of(context).primaryColor,
                  body: NestedScrollView(
                    controller: controller,
                    headerSliverBuilder: (context, innerBoxIsScrolled) =>
                        <Widget>[
                      SliverAppBar(
                        backgroundColor: Color(0xFFE57697),
                        automaticallyImplyLeading: false,
                        pinned: false,
                        expandedHeight: 260.0,
                        flexibleSpace: FlexibleSpaceBar(
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                color: Color(0xFFE57697),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 25.0),
                                child: Container(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Spacer(flex: 5),
                                      main.prefs.getString("googleimage") ==
                                              null
                                          ? Container()
                                          : Container(
                                              decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          5000),
                                                  boxShadow: [
                                                    BoxShadow(
                                                        blurRadius: 16,
                                                        offset: Offset(0, 4),
                                                        color: Color(0xFF000000)
                                                            .withOpacity(0.24))
                                                  ]),
                                              child: CircleAvatar(
                                                radius: 50,
                                                backgroundImage: NetworkImage(
                                                    main.prefs.getString(
                                                        "googleimage")),
                                              ),
                                            ),
                                      Spacer(flex: 2),
                                      main.prefs.getString("name") == null
                                          ? Container()
                                          : Text(
                                              main.prefs.getString("name"),
                                              style: TextStyle(
                                                  fontFamily: "Proxima Nova",
                                                  color: Colors.white,
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.w700),
                                            ),
                                      Spacer(flex: 1),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: <Widget>[
                                          Spacer(flex: 3),
                                          Row(
                                            children: <Widget>[
                                              Text(
                                                favCount.toString() + " ",
                                                style: TextStyle(
                                                    fontFamily: "Proxima Nova",
                                                    fontSize: 24,
                                                    color: Colors.white70,
                                                    fontWeight:
                                                        FontWeight.normal),
                                              ),
                                              Icon(
                                                JamIcons.heart,
                                                color: Colors.white70,
                                              ),
                                            ],
                                          ),
                                          Spacer(flex: 1),
                                          Row(
                                            children: <Widget>[
                                              Text(
                                                Provider.of<ProfileWallProvider>(
                                                            context)
                                                        .len
                                                        .toString() +
                                                    " ",
                                                style: TextStyle(
                                                    fontFamily: "Proxima Nova",
                                                    fontSize: 24,
                                                    color: Colors.white70,
                                                    fontWeight:
                                                        FontWeight.normal),
                                              ),
                                              Icon(
                                                JamIcons.picture,
                                                color: Colors.white70,
                                              ),
                                            ],
                                          ),
                                          Spacer(flex: 3),
                                        ],
                                      ),
                                      Spacer(flex: 4),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverAppBar(
                        backgroundColor: Color(0xFFE57697),
                        automaticallyImplyLeading: false,
                        pinned: true,
                        titleSpacing: 0,
                        expandedHeight:
                            main.prefs.getBool("isLoggedin") ? 50 : 0,
                        title: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: 57,
                          child: Container(
                            color: Theme.of(context).primaryColor,
                            child: SizedBox.expand(
                              child: TabBar(
                                  indicatorColor: Color(0xFFFFFFFF),
                                  indicatorSize: TabBarIndicatorSize.label,
                                  unselectedLabelColor:
                                      Color(0xFFFFFFFF).withOpacity(0.5),
                                  labelColor: Color(0xFFFFFFFF),
                                  tabs: [
                                    Tab(
                                      icon: Icon(JamIcons.picture),
                                    ),
                                    Tab(
                                      icon: Icon(JamIcons.settings_alt),
                                    )
                                  ]),
                            ),
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: ProfileLoader(
                          future: Provider.of<ProfileWallProvider>(context)
                              .getProfileWalls(),
                        ),
                      ),
                      SettingsList()
                    ]),
                  ),
                ),
              )
            : Scaffold(
                backgroundColor: Theme.of(context).primaryColor,
                body:
                    CustomScrollView(controller: controller, slivers: <Widget>[
                  SliverAppBar(
                    backgroundColor: Color(0xFFE57697),
                    automaticallyImplyLeading: false,
                    pinned: false,
                    expandedHeight: 280.0,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          Stack(
                            children: <Widget>[
                              Container(
                                color: Color(0xFFE57697),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                                child: Center(
                                  child: SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width / 2,
                                    child: FlareActor(
                                      "assets/animations/Text.flr",
                                      isPaused: false,
                                      alignment: Alignment.center,
                                      animation: "Untitled",
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                      delegate: SliverChildListDelegate([
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: DownloadList(),
                    ),
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
                        main.prefs.getBool("darkMode") == null
                            ? analytics.logEvent(
                                name: 'theme_changed',
                                parameters: {'type': 'dark'})
                            : main.prefs.getBool("darkMode")
                                ? analytics.logEvent(
                                    name: 'theme_changed',
                                    parameters: {'type': 'light'})
                                : analytics.logEvent(
                                    name: 'theme_changed',
                                    parameters: {'type': 'dark'});
                        Provider.of<ThemeModel>(context, listen: false)
                            .toggleTheme();
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
                    ListTile(
                      onTap: () {
                        Dialog loaderDialog = Dialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          child: Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Theme.of(context).primaryColor),
                            width: MediaQuery.of(context).size.width * .7,
                            height: MediaQuery.of(context).size.height * .3,
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        );
                        if (!main.prefs.getBool("isLoggedin")) {
                          showDialog(
                              barrierDismissible: false,
                              context: context,
                              builder: (BuildContext context) => loaderDialog);
                          globals.gAuth.signInWithGoogle().then((value) {
                            toasts.successLog();
                            main.prefs.setBool("isLoggedin", true);
                            Navigator.pop(context);
                            main.RestartWidget.restartApp(context);
                          }).catchError((e) {
                            print(e);
                            Navigator.pop(context);
                            main.prefs.setBool("isLoggedin", false);
                            toasts.error(
                                "Something went wrong, please try again!");
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
                    ),
                    PrismList(),
                    StudioList(),
                  ]))
                ]),
              ));
  }
}

class SettingsList extends StatefulWidget {
  @override
  _SettingsListState createState() => _SettingsListState();
}

class _SettingsListState extends State<SettingsList> {
  @override
  Widget build(BuildContext context) {
    return ListView(children: <Widget>[
      DownloadList(),
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
          main.prefs.getBool("darkMode") == null
              ? analytics
                  .logEvent(name: 'theme_changed', parameters: {'type': 'dark'})
              : main.prefs.getBool("darkMode")
                  ? analytics.logEvent(
                      name: 'theme_changed', parameters: {'type': 'light'})
                  : analytics.logEvent(
                      name: 'theme_changed', parameters: {'type': 'dark'});
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
              : main.prefs.getBool("darkMode") ? "Light Mode" : "Dark Mode",
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
                Dialog loaderDialog = Dialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Theme.of(context).primaryColor),
                    width: MediaQuery.of(context).size.width * .7,
                    height: MediaQuery.of(context).size.height * .3,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );
                if (!main.prefs.getBool("isLoggedin")) {
                  showDialog(
                      barrierDismissible: false,
                      context: context,
                      builder: (BuildContext context) => loaderDialog);
                  globals.gAuth.signInWithGoogle().then((value) {
                    toasts.successLog();
                    main.prefs.setBool("isLoggedin", true);
                    Navigator.pop(context);
                    main.RestartWidget.restartApp(context);
                  }).catchError((e) {
                    print(e);
                    Navigator.pop(context);
                    main.prefs.setBool("isLoggedin", false);
                    toasts.error("Something went wrong, please try again!");
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
                            height: 50,
                            width: 250,
                            child: Center(
                              child: Text(
                                "Do you want remove all your favourites?",
                                style: Theme.of(context).textTheme.headline4,
                              ),
                            ),
                          ),
                          actions: <Widget>[
                            FlatButton(
                              shape: StadiumBorder(),
                              onPressed: () {
                                Navigator.of(context).pop();
                                toasts.clearFav();
                                Provider.of<FavouriteProvider>(context,
                                        listen: false)
                                    .deleteData();
                              },
                              child: Text(
                                'YES',
                                style: TextStyle(
                                  fontSize: 16.0,
                                  color: Color(0xFFE57697),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FlatButton(
                                shape: StadiumBorder(),
                                color: Color(0xFFE57697),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text(
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
                      main.prefs.getString("email"),
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
      PrismList(),
      StudioList(),
    ]);
  }
}
