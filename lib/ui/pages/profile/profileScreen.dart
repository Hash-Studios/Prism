import 'dart:async';
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/data/profile/wallpaper/profileWallProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/favourite/favLoader.dart';
import 'package:Prism/ui/widgets/profile/generalList.dart';
import 'package:Prism/ui/widgets/profile/downloadList.dart';
import 'package:Prism/ui/widgets/profile/premiumList.dart';
import 'package:Prism/ui/widgets/profile/prismList.dart';
import 'package:Prism/ui/widgets/profile/studioList.dart';
import 'package:Prism/ui/widgets/home/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/inheritedScrollControllerProvider.dart';
import 'package:Prism/ui/widgets/profile/profileLoader.dart';
import 'package:Prism/ui/widgets/profile/userList.dart';
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
    return Scaffold(
      body: BottomBar(
        child: ProfileChild(),
      ),
    );
  }
}

class ProfileChild extends StatefulWidget {
  @override
  _ProfileChildState createState() => _ProfileChildState();
}

class _ProfileChildState extends State<ProfileChild> {
  int favCount = main.prefs.get('userFavs') ?? 0;
  int profileCount = main.prefs.get('userPosts') ?? 0;
  final ScrollController scrollController = ScrollController();
  @override
  void initState() {
    checkFav();
    super.initState();
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    print(navStack);
    return true;
  }

  Future checkFav() async {
    if (main.prefs.get("isLoggedin")) {
      await Provider.of<FavouriteProvider>(context, listen: false)
          .countFav()
          .then(
        (value) {
          print(value);
          setState(
            () {
              favCount = value;
              main.prefs.put('userFavs', value);
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
        child: main.prefs.get("isLoggedin")
            ? DefaultTabController(
                length: 3,
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
                                      main.prefs.get("googleimage") == null
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
                                                    main.prefs
                                                        .get("googleimage")),
                                              ),
                                            ),
                                      Spacer(flex: 2),
                                      main.prefs.get("name") == null
                                          ? Container()
                                          : !main.prefs.get('premium')
                                              ? Text(
                                                  main.prefs.get("name"),
                                                  style: TextStyle(
                                                      fontFamily:
                                                          "Proxima Nova",
                                                      color: Colors.white,
                                                      fontSize: 32,
                                                      fontWeight:
                                                          FontWeight.w700),
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: <Widget>[
                                                    Text(
                                                      main.prefs.get("name"),
                                                      style: TextStyle(
                                                          fontFamily:
                                                              "Proxima Nova",
                                                          color: Colors.white,
                                                          fontSize: 32,
                                                          fontWeight:
                                                              FontWeight.w700),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 8.0),
                                                      child: Container(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                vertical: 3,
                                                                horizontal: 5),
                                                        decoration: BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        50),
                                                            color: Color(
                                                                0xFFFFFFFF)),
                                                        child: Text(
                                                          "PRO",
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodyText2
                                                              .copyWith(
                                                                  fontSize: 10,
                                                                  color: Color(
                                                                      0xFFE57697)),
                                                        ),
                                                      ),
                                                    )
                                                  ],
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
                                                JamIcons.heart_f,
                                                color: Colors.white70,
                                              ),
                                            ],
                                          ),
                                          Spacer(flex: 1),
                                          Row(
                                            children: <Widget>[
                                              FutureBuilder(
                                                  future: Provider.of<
                                                              ProfileWallProvider>(
                                                          context,
                                                          listen: false)
                                                      .getProfileWallsLength(),
                                                  builder: (context, snapshot) {
                                                    return Text(
                                                      snapshot.data == null
                                                          ? profileCount
                                                                  .toString() +
                                                              " "
                                                          : snapshot.data
                                                                  .toString() +
                                                              " ",
                                                      style: TextStyle(
                                                          fontFamily:
                                                              "Proxima Nova",
                                                          fontSize: 24,
                                                          color: Colors.white70,
                                                          fontWeight: FontWeight
                                                              .normal),
                                                    );
                                                  }),
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
                        expandedHeight: main.prefs.get("isLoggedin") ? 50 : 0,
                        title: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: 57,
                          child: Container(
                            color: Theme.of(context).primaryColor,
                            child: SizedBox.expand(
                              child: TabBar(
                                  indicatorColor: Theme.of(context).accentColor,
                                  indicatorSize: TabBarIndicatorSize.label,
                                  unselectedLabelColor:
                                      Color(0xFFFFFFFF).withOpacity(0.5),
                                  labelColor: Color(0xFFFFFFFF),
                                  tabs: [
                                    Tab(
                                      icon: Icon(
                                        JamIcons.heart_f,
                                        color: Theme.of(context).accentColor,
                                      ),
                                    ),
                                    Tab(
                                      icon: Icon(
                                        JamIcons.picture,
                                        color: Theme.of(context).accentColor,
                                      ),
                                    ),
                                    Tab(
                                      icon: Icon(
                                        JamIcons.settings_alt,
                                        color: Theme.of(context).accentColor,
                                      ),
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
                        child: FavLoader(
                          future: Provider.of<FavouriteProvider>(context,
                                  listen: false)
                              .getDataBase(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: ProfileLoader(
                          future: Provider.of<ProfileWallProvider>(context,
                                  listen: false)
                              .getProfileWalls(),
                        ),
                      ),
                      ListView(children: <Widget>[
                        PremiumList(),
                        DownloadList(),
                        GeneralList(),
                        UserList(),
                        PrismList(),
                        StudioList(scrollController: controller),
                      ])
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
                      padding: const EdgeInsets.only(top: 10),
                      child: PremiumList(),
                    ),
                    DownloadList(),
                    GeneralList(),
                    UserList(),
                    PrismList(),
                    StudioList(),
                  ]))
                ]),
              ));
  }
}
