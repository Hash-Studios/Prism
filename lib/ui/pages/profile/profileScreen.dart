import 'dart:async';
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/data/favourites/provider/favouriteSetupProvider.dart';
import 'package:Prism/data/profile/wallpaper/profileSetupProvider.dart';
import 'package:Prism/data/profile/wallpaper/profileWallProvider.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/profile/aboutList.dart';
import 'package:Prism/ui/widgets/profile/drawerWidget.dart';
import 'package:Prism/ui/widgets/profile/generalList.dart';
import 'package:Prism/ui/widgets/profile/downloadList.dart';
import 'package:Prism/ui/widgets/profile/premiumList.dart';
import 'package:Prism/ui/widgets/profile/studioList.dart';
import 'package:Prism/ui/widgets/home/core/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/core/inheritedScrollControllerProvider.dart';
import 'package:Prism/ui/widgets/profile/uploadedWallsLoader.dart';
import 'package:Prism/ui/widgets/profile/uploadedSetupsLoader.dart';
import 'package:Prism/ui/widgets/profile/userList.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:provider/provider.dart';
import 'package:Prism/theme/config.dart' as config;
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:Prism/global/svgAssets.dart';

final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: scaffoldKey,
        body: BottomBar(
          child: ProfileChild(),
        ),
        endDrawer: ProfileDrawer());
  }
}

class ProfileChild extends StatefulWidget {
  @override
  _ProfileChildState createState() => _ProfileChildState();
}

class _ProfileChildState extends State<ProfileChild> {
  int favCount = main.prefs.get('userFavs') as int ?? 0;
  int profileCount = ((main.prefs.get('userPosts') as int) ?? 0) +
      ((main.prefs.get('userSetups') as int) ?? 0);
  final ScrollController scrollController = ScrollController();
  @override
  void initState() {
    checkFav();
    super.initState();
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  Future checkFav() async {
    if (main.prefs.get("isLoggedin") as bool) {
      await Provider.of<FavouriteProvider>(context, listen: false)
          .countFav()
          .then(
        (value) async {
          await Provider.of<FavouriteSetupProvider>(context, listen: false)
              .countFavSetups()
              .then((value2) {
            debugPrint(value.toString());
            debugPrint(value2.toString());
            setState(
              () {
                favCount = value + value2;
                main.prefs.put('userFavs', favCount);
              },
            );
          });
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
        child: main.prefs.get("isLoggedin") as bool
            ? DefaultTabController(
                length: 2,
                child: Scaffold(
                  backgroundColor: Theme.of(context).primaryColor,
                  body: NestedScrollView(
                    controller: controller,
                    headerSliverBuilder: (context, innerBoxIsScrolled) =>
                        <Widget>[
                      SliverAppBar(
                        actions: main.prefs.get("name") == null &&
                                main.prefs.get("email") == null &&
                                main.prefs.get("googleimage") == null
                            ? []
                            : [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: IconButton(
                                      icon: const Icon(JamIcons.share_alt),
                                      onPressed: () {
                                        createUserDynamicLink(
                                            main.prefs.get("name").toString(),
                                            main.prefs.get("email").toString(),
                                            main.prefs
                                                .get("googleimage")
                                                .toString(),
                                            main.prefs.get("premium") as bool,
                                            main.prefs.get("twitter") != ""
                                                ? main.prefs
                                                        .get("twitter")
                                                        .toString()
                                                        .split(
                                                            "https://www.twitter.com/")[
                                                    1]
                                                : "",
                                            main.prefs.get("instagram") != ""
                                                ? main.prefs
                                                    .get("instagram")
                                                    .toString()
                                                    .split(
                                                        "https://www.instagram.com/")[1]
                                                : "");
                                      }),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: IconButton(
                                      icon: const Icon(JamIcons.menu),
                                      onPressed: () {
                                        scaffoldKey.currentState
                                            .openEndDrawer();
                                      }),
                                )
                              ],
                        backgroundColor: config.Colors().mainAccentColor(1),
                        automaticallyImplyLeading: false,
                        expandedHeight: 260.0,
                        flexibleSpace: FlexibleSpaceBar(
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                color: config.Colors().mainAccentColor(1),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 25.0),
                                child: Column(
                                  children: [
                                    const Spacer(flex: 5),
                                    main.prefs.get("googleimage") == null
                                        ? Container()
                                        : Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5000),
                                                    boxShadow: [
                                                      BoxShadow(
                                                          blurRadius: 16,
                                                          offset: const Offset(
                                                              0, 4),
                                                          color: const Color(
                                                                  0xFF000000)
                                                              .withOpacity(
                                                                  0.24))
                                                    ]),
                                                child: CircleAvatar(
                                                  radius: 50,
                                                  backgroundImage: NetworkImage(
                                                      main.prefs
                                                          .get("googleimage")
                                                          .toString()),
                                                ),
                                              ),
                                              globals.verifiedUsers.contains(
                                                      main.prefs
                                                          .get("email")
                                                          .toString())
                                                  ? Positioned(
                                                      top: 0,
                                                      left: 70,
                                                      child: Container(
                                                        width: 30,
                                                        height: 30,
                                                        child: SvgPicture
                                                            .string(verifiedIcon
                                                                .replaceAll(
                                                                    "E57697",
                                                                    "FFFFFF")),
                                                      ),
                                                    )
                                                  : Container(),
                                            ],
                                          ),
                                    const Spacer(flex: 2),
                                    main.prefs.get("name") == null
                                        ? Container()
                                        : main.prefs.get('premium') == false
                                            ? Text(
                                                main.prefs
                                                    .get("name")
                                                    .toString(),
                                                style: const TextStyle(
                                                    fontFamily: "Proxima Nova",
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
                                                    main.prefs
                                                        .get("name")
                                                        .toString(),
                                                    style: const TextStyle(
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
                                                      padding: const EdgeInsets
                                                              .symmetric(
                                                          vertical: 3,
                                                          horizontal: 5),
                                                      decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(50),
                                                          color: const Color(
                                                              0xFFFFFFFF)),
                                                      child: Text(
                                                        "PRO",
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyText2
                                                            .copyWith(
                                                                fontSize: 10,
                                                                color: Color(main
                                                                        .prefs
                                                                        .get(
                                                                            "mainAccentColor")
                                                                    as int)),
                                                      ),
                                                    ),
                                                  )
                                                ],
                                              ),
                                    const Spacer(),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        const Spacer(flex: 3),
                                        Row(
                                          children: <Widget>[
                                            Text(
                                              "${favCount.toString()} ",
                                              style: const TextStyle(
                                                  fontFamily: "Proxima Nova",
                                                  fontSize: 24,
                                                  color: Colors.white70,
                                                  fontWeight:
                                                      FontWeight.normal),
                                            ),
                                            const Icon(
                                              JamIcons.heart_f,
                                              color: Colors.white70,
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
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
                                                        ? "${profileCount.toString()} "
                                                        : "${snapshot.data.toString()} ",
                                                    style: const TextStyle(
                                                        fontFamily:
                                                            "Proxima Nova",
                                                        fontSize: 24,
                                                        color: Colors.white70,
                                                        fontWeight:
                                                            FontWeight.normal),
                                                  );
                                                }),
                                            const Icon(
                                              JamIcons.picture,
                                              color: Colors.white70,
                                            ),
                                          ],
                                        ),
                                        const Spacer(flex: 3),
                                      ],
                                    ),
                                    const Spacer(),
                                    main.prefs.get("twitter") != "" &&
                                            main.prefs.get("twitter") !=
                                                "https://www.twitter.com/"
                                        ? GestureDetector(
                                            onTap: () {
                                              launch(main.prefs
                                                  .get("twitter")
                                                  .toString());
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              // mainAxisAlignment:
                                              //     MainAxisAlignment.start,
                                              children: <Widget>[
                                                const Icon(
                                                  JamIcons.twitter,
                                                  color: Colors.white70,
                                                ),
                                                Text(
                                                  ' ${main.prefs.get("twitter").toString().split("https://www.twitter.com/")[1]}',
                                                  style: const TextStyle(
                                                      fontFamily:
                                                          "Proxima Nova",
                                                      fontSize: 20,
                                                      color: Colors.white70,
                                                      fontWeight:
                                                          FontWeight.normal),
                                                ),
                                              ],
                                            ),
                                          )
                                        : const Spacer(),
                                    const Spacer(),
                                    main.prefs.get("instagram") != "" &&
                                            main.prefs.get("instagram") !=
                                                "https://www.instagram.com/"
                                        ? GestureDetector(
                                            onTap: () {
                                              launch(main.prefs
                                                  .get("instagram")
                                                  .toString());
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              // mainAxisAlignment:
                                              //     MainAxisAlignment.start,
                                              children: <Widget>[
                                                const Icon(
                                                  JamIcons.instagram,
                                                  color: Colors.white70,
                                                ),
                                                Text(
                                                  ' ${main.prefs.get("instagram").toString().split("https://www.instagram.com/")[1]}',
                                                  style: const TextStyle(
                                                      fontFamily:
                                                          "Proxima Nova",
                                                      fontSize: 20,
                                                      color: Colors.white70,
                                                      fontWeight:
                                                          FontWeight.normal),
                                                ),
                                              ],
                                            ),
                                          )
                                        : const Spacer(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverAppBar(
                        backgroundColor: config.Colors().mainAccentColor(1),
                        automaticallyImplyLeading: false,
                        pinned: true,
                        titleSpacing: 0,
                        expandedHeight:
                            main.prefs.get("isLoggedin") as bool ? 50 : 0,
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
                                      const Color(0xFFFFFFFF).withOpacity(0.5),
                                  labelColor: const Color(0xFFFFFFFF),
                                  tabs: [
                                    Tab(
                                      icon: Icon(
                                        JamIcons.picture,
                                        color: Theme.of(context).accentColor,
                                      ),
                                    ),
                                    Tab(
                                      icon: Icon(
                                        JamIcons.instant_picture,
                                        color: Theme.of(context).accentColor,
                                      ),
                                    ),
                                  ]),
                            ),
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: ProfileLoader(
                          future: Provider.of<ProfileWallProvider>(context,
                                  listen: false)
                              .getProfileWalls(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: UploadedSetupsLoader(
                          future: Provider.of<ProfileSetupProvider>(context,
                                  listen: false)
                              .getProfileSetups(),
                        ),
                      ),
                    ]),
                  ),
                ),
              )
            : Scaffold(
                backgroundColor: Theme.of(context).primaryColor,
                body:
                    CustomScrollView(controller: controller, slivers: <Widget>[
                  SliverAppBar(
                    backgroundColor: config.Colors().mainAccentColor(1),
                    automaticallyImplyLeading: false,
                    expandedHeight: 280.0,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          Stack(
                            children: <Widget>[
                              Container(
                                color: config.Colors().mainAccentColor(1),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                                child: Center(
                                  child: SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width / 2,
                                    child: const FlareActor(
                                      "assets/animations/Text.flr",
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
                    const StudioList(),
                    AboutList(),
                    const SizedBox(
                      height: 300,
                    ),
                    // const SizedBox(
                    //   height: 300,
                    //   child: FlareActor(
                    //     "assets/animations/Update.flr",
                    //     animation: "update",
                    //   ),
                    // ),
                  ]))
                ]),
              ));
  }
}
