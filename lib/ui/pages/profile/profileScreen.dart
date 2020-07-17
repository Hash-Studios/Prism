import 'dart:async';
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/data/profile/wallpaper/profileWallProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/home/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/inheritedScrollControllerProvider.dart';
import 'package:Prism/ui/widgets/profile/profileLoader.dart';
import 'package:Prism/ui/widgets/profile/settingsList.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:provider/provider.dart';

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
    checkProfileWalls();
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

  Future checkProfileWalls() async {
    if (main.prefs.getBool("isLoggedin")) {
      await Provider.of<ProfileWallProvider>(context, listen: false)
          .countProfileWalls()
          .then(
        (value) {
          print(value);
          setState(
            () {
              profileCount = value;
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
      child: DefaultTabController(
        length: main.prefs.getBool("isLoggedin") ? 2 : 1,
        child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          body: NestedScrollView(
            controller: controller,
            headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
              SliverAppBar(
                backgroundColor: Color(0xFFE57697),
                automaticallyImplyLeading: false,
                pinned: false,
                expandedHeight: 240.0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      main.prefs.getBool("isLoggedin")
                          ? Container(
                              color: Color(0xFFE57697),
                            )
                          : Stack(
                              children: <Widget>[
                                Container(
                                  color: Color(0xFFE57697),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 20, 0, 0),
                                  child: Center(
                                    child: FlareActor(
                                      "assets/animations/Text.flr",
                                      isPaused: false,
                                      alignment: Alignment.center,
                                      animation: "Untitled",
                                    ),
                                  ),
                                )
                              ],
                            ),
                      main.prefs.getBool("isLoggedin")
                          ? Padding(
                              padding: const EdgeInsets.only(top: 35.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
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
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            8, 15, 8, 6),
                                        child: main.prefs.getString("name") ==
                                                null
                                            ? Container()
                                            : Text(
                                                main.prefs.getString("name"),
                                                style: TextStyle(
                                                    fontFamily: "Proxima Nova",
                                                    color: Colors.white,
                                                    fontSize: 32,
                                                    fontWeight:
                                                        FontWeight.w700),
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
                                                      fontFamily:
                                                          "Proxima Nova",
                                                      color: Colors.white70,
                                                      fontSize: 22,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                )
                                              ]),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: RichText(
                                          text: TextSpan(
                                              text: profileCount.toString(),
                                              style: TextStyle(
                                                  fontFamily: "Proxima Nova",
                                                  fontSize: 24,
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.w700),
                                              children: [
                                                TextSpan(
                                                  text: " Uploads",
                                                  style: TextStyle(
                                                      fontFamily:
                                                          "Proxima Nova",
                                                      color: Colors.white70,
                                                      fontSize: 22,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                )
                                              ]),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            )
                          : Container(),
                    ],
                  ),
                ),
              ),
              SliverAppBar(
                backgroundColor: Color(0xFFE57697),
                automaticallyImplyLeading: false,
                pinned: true,
                expandedHeight: main.prefs.getBool("isLoggedin") ? 50 : 0,
                title: TabBar(
                    indicatorColor: main.prefs.getBool("isLoggedin")
                        ? Color(0xFFFFFFFF)
                        : Color(0xFFE57697),
                    indicatorSize: TabBarIndicatorSize.label,
                    unselectedLabelColor: Color(0xFFFFFFFF).withOpacity(0.5),
                    labelColor: Color(0xFFFFFFFF),
                    tabs: main.prefs.getBool("isLoggedin")
                        ? [
                            Tab(
                              icon: Icon(JamIcons.picture),
                            ),
                            Tab(
                              icon: Icon(JamIcons.settings_alt),
                            )
                          ]
                        : [
                            Tab(
                              icon: Icon(JamIcons.settings_alt),
                            )
                          ]),
              ),
            ],
            body: TabBarView(
                children: main.prefs.getBool("isLoggedin")
                    ? [
                        ProfileLoader(
                          future: Provider.of<ProfileWallProvider>(context,
                                  listen: false)
                              .getProfileWalls(),
                        ),
                        SettingsList()
                      ]
                    : [SettingsList()]),
          ),
        ),
      ),
    );
  }
}
