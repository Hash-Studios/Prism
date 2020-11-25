import 'dart:async';
import 'dart:math';
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/data/favourites/provider/favouriteSetupProvider.dart';
import 'package:Prism/data/profile/wallpaper/getUserProfile.dart';
import 'package:Prism/data/profile/wallpaper/profileSetupProvider.dart';
import 'package:Prism/data/profile/wallpaper/profileWallProvider.dart';
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
import 'package:animations/animations.dart';
import 'package:confetti/confetti.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:provider/provider.dart';
import 'package:Prism/theme/config.dart' as config;
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
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
        endDrawer: Container(
            width: MediaQuery.of(context).size.width * 0.66,
            child: ProfileDrawer()));
  }
}

class ProfileChild extends StatefulWidget {
  @override
  _ProfileChildState createState() => _ProfileChildState();
}

class _ProfileChildState extends State<ProfileChild> {
  final TextEditingController _twitterController = TextEditingController();
  final TextEditingController _igController = TextEditingController();
  ConfettiController _controllerBottomCenter;
  int favCount = main.prefs.get('userFavs') as int ?? 0;
  int profileCount = ((main.prefs.get('userPosts') as int) ?? 0) +
      ((main.prefs.get('userSetups') as int) ?? 0);
  final ScrollController scrollController = ScrollController();
  @override
  void initState() {
    checkFav();
    _controllerBottomCenter =
        ConfettiController(duration: const Duration(seconds: 1));
    super.initState();
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  @override
  void dispose() {
    _controllerBottomCenter.dispose();
    super.dispose();
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
            if (mounted) {
              setState(
                () {
                  favCount = value + value2;
                  main.prefs.put('userFavs', favCount);
                },
              );
            }
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
                child: Stack(
                  children: [
                    Scaffold(
                      backgroundColor: Theme.of(context).primaryColor,
                      body: NestedScrollView(
                        controller: controller,
                        headerSliverBuilder: (context, innerBoxIsScrolled) =>
                            <Widget>[
                          SliverAppBar(
                            actions: main.prefs.get('isLoggedin') == false
                                ? []
                                : [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: IconButton(
                                          icon: Icon(JamIcons.menu,
                                              color: Theme.of(context)
                                                  .accentColor),
                                          onPressed: () {
                                            scaffoldKey.currentState
                                                .openEndDrawer();
                                          }),
                                    )
                                  ],
                            backgroundColor: config.Colors().mainAccentColor(1),
                            automaticallyImplyLeading: false,
                            expandedHeight: 200.0,
                            flexibleSpace: FlexibleSpaceBar(
                              background: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(
                                    color: config.Colors().mainAccentColor(1),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 25, 16, 0),
                                    child: Column(
                                      children: [
                                        const Spacer(flex: 5),
                                        Table(
                                          columnWidths: const {
                                            0: FlexColumnWidth(3),
                                            1: FlexColumnWidth(5)
                                          },
                                          children: [
                                            TableRow(children: [
                                              TableCell(
                                                child: main.prefs.get(
                                                            "googleimage") ==
                                                        null
                                                    ? Container()
                                                    : Stack(
                                                        alignment:
                                                            Alignment.center,
                                                        children: [
                                                          Container(
                                                            decoration: BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            5000),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                      blurRadius:
                                                                          16,
                                                                      offset:
                                                                          const Offset(
                                                                              0,
                                                                              4),
                                                                      color: const Color(
                                                                              0xFF000000)
                                                                          .withOpacity(
                                                                              0.24))
                                                                ]),
                                                            child:
                                                                GestureDetector(
                                                              onTap: () {
                                                                _controllerBottomCenter
                                                                    .play();
                                                              },
                                                              child:
                                                                  CircleAvatar(
                                                                radius: 50,
                                                                backgroundImage:
                                                                    NetworkImage(main
                                                                        .prefs
                                                                        .get(
                                                                            "googleimage")
                                                                        .toString()),
                                                              ),
                                                            ),
                                                          ),
                                                          globals.verifiedUsers
                                                                  .contains(main
                                                                      .prefs
                                                                      .get(
                                                                          "email")
                                                                      .toString())
                                                              ? Positioned(
                                                                  top: 5,
                                                                  left: 100,
                                                                  child:
                                                                      Container(
                                                                    width: 30,
                                                                    height: 30,
                                                                    child: SvgPicture.string(verifiedIcon.replaceAll(
                                                                        "E57697",
                                                                        "FFFFFF")),
                                                                  ),
                                                                )
                                                              : Container(),
                                                        ],
                                                      ),
                                              ),
                                              TableCell(
                                                verticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .bottom,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 20),
                                                  child: main.prefs
                                                              .get("name") ==
                                                          null
                                                      ? Container()
                                                      : main.prefs.get(
                                                                  'premium') ==
                                                              false
                                                          ? Text(
                                                              main.prefs
                                                                  .get("name")
                                                                  .toString()
                                                                  .toUpperCase(),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: TextStyle(
                                                                  fontFamily:
                                                                      "Proxima Nova",
                                                                  color: Theme.of(
                                                                          context)
                                                                      .accentColor,
                                                                  fontSize: 20,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600),
                                                            )
                                                          : Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: <
                                                                  Widget>[
                                                                Text(
                                                                  main.prefs
                                                                      .get(
                                                                          "name")
                                                                      .toString()
                                                                      .toUpperCase(),
                                                                  style: TextStyle(
                                                                      fontFamily:
                                                                          "Proxima Nova",
                                                                      color: Theme.of(
                                                                              context)
                                                                          .accentColor,
                                                                      fontSize:
                                                                          20,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600),
                                                                ),
                                                                Padding(
                                                                  padding: const EdgeInsets
                                                                          .only(
                                                                      left:
                                                                          6.0),
                                                                  child:
                                                                      Container(
                                                                    padding: const EdgeInsets
                                                                            .symmetric(
                                                                        vertical:
                                                                            2,
                                                                        horizontal:
                                                                            4),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              50),
                                                                      color: Theme.of(
                                                                              context)
                                                                          .accentColor,
                                                                    ),
                                                                    child: Text(
                                                                      "PRO",
                                                                      style: Theme.of(
                                                                              context)
                                                                          .textTheme
                                                                          .bodyText2
                                                                          .copyWith(
                                                                            fontSize:
                                                                                9,
                                                                            color:
                                                                                Color(main.prefs.get("mainAccentColor") as int),
                                                                          ),
                                                                    ),
                                                                  ),
                                                                )
                                                              ],
                                                            ),
                                                ),
                                              ),
                                            ]),
                                            TableRow(children: [
                                              TableCell(
                                                verticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    IconButton(
                                                        icon: Icon(
                                                          JamIcons.twitter,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                        ),
                                                        onPressed: main.prefs.get(
                                                                        "twitter") !=
                                                                    null &&
                                                                main.prefs.get(
                                                                        "twitter") !=
                                                                    "" &&
                                                                main.prefs.get(
                                                                        "twitter") !=
                                                                    "https://www.twitter.com/"
                                                            ? () {
                                                                launch(main
                                                                    .prefs
                                                                    .get(
                                                                        "twitter")
                                                                    .toString());
                                                              }
                                                            : () async {
                                                                showModal(
                                                                  context:
                                                                      context,
                                                                  configuration:
                                                                      const FadeScaleTransitionConfiguration(),
                                                                  builder:
                                                                      (context) =>
                                                                          AlertDialog(
                                                                    shape:
                                                                        const RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .all(
                                                                        Radius.circular(
                                                                            10),
                                                                      ),
                                                                    ),
                                                                    content:
                                                                        Container(
                                                                      height:
                                                                          100,
                                                                      width:
                                                                          250,
                                                                      child:
                                                                          Center(
                                                                        child:
                                                                            Column(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.spaceEvenly,
                                                                          children: [
                                                                            Text(
                                                                              "Enter your Twitter username",
                                                                              style: Theme.of(context).textTheme.headline4,
                                                                            ),
                                                                            Container(
                                                                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(500), color: Theme.of(context).hintColor),
                                                                              child: TextField(
                                                                                cursorColor: config.Colors().mainAccentColor(1),
                                                                                style: Theme.of(context).textTheme.headline5.copyWith(color: Theme.of(context).accentColor),
                                                                                controller: _twitterController,
                                                                                decoration: InputDecoration(
                                                                                  contentPadding: const EdgeInsets.only(left: 30, top: 15),
                                                                                  border: InputBorder.none,
                                                                                  disabledBorder: InputBorder.none,
                                                                                  enabledBorder: InputBorder.none,
                                                                                  focusedBorder: InputBorder.none,
                                                                                  hintText: "Ex - PrismWallpapers",
                                                                                  hintStyle: Theme.of(context).textTheme.headline5.copyWith(fontSize: 14, color: Theme.of(context).accentColor),
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
                                                                    actions: <
                                                                        Widget>[
                                                                      FlatButton(
                                                                        shape: RoundedRectangleBorder(
                                                                            borderRadius:
                                                                                BorderRadius.circular(5)),
                                                                        onPressed:
                                                                            () {
                                                                          Navigator.of(context)
                                                                              .pop();
                                                                        },
                                                                        child:
                                                                            Text(
                                                                          'CANCEL',
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                16.0,
                                                                            color:
                                                                                config.Colors().mainAccentColor(1),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      Padding(
                                                                        padding:
                                                                            const EdgeInsets.only(right: 8.0),
                                                                        child:
                                                                            FlatButton(
                                                                          shape:
                                                                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                                                          color:
                                                                              config.Colors().mainAccentColor(1),
                                                                          onPressed:
                                                                              () async {
                                                                            Navigator.of(context).pop();
                                                                            await setUserTwitter("https://www.twitter.com/${_twitterController.text}",
                                                                                main.prefs.get("id").toString());
                                                                            toasts.codeSend("Successfully linked!");
                                                                          },
                                                                          child:
                                                                              const Text(
                                                                            'SAVE',
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 16.0,
                                                                              color: Colors.white,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                    backgroundColor:
                                                                        Theme.of(context)
                                                                            .primaryColor,
                                                                  ),
                                                                );
                                                              }),
                                                    IconButton(
                                                        icon: Icon(
                                                          JamIcons.instagram,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                        ),
                                                        onPressed: main.prefs.get(
                                                                        "instagram") !=
                                                                    null &&
                                                                main.prefs.get(
                                                                        "instagram") !=
                                                                    "" &&
                                                                main.prefs.get(
                                                                        "instagram") !=
                                                                    "https://www.instagram.com/"
                                                            ? () {
                                                                launch(main
                                                                    .prefs
                                                                    .get(
                                                                        "instagram")
                                                                    .toString());
                                                              }
                                                            : () async {
                                                                showModal(
                                                                  context:
                                                                      context,
                                                                  configuration:
                                                                      const FadeScaleTransitionConfiguration(),
                                                                  builder:
                                                                      (context) =>
                                                                          AlertDialog(
                                                                    shape:
                                                                        const RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .all(
                                                                        Radius.circular(
                                                                            10),
                                                                      ),
                                                                    ),
                                                                    content:
                                                                        Container(
                                                                      height:
                                                                          100,
                                                                      width:
                                                                          250,
                                                                      child:
                                                                          Center(
                                                                        child:
                                                                            Column(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.spaceEvenly,
                                                                          children: [
                                                                            Text(
                                                                              "Enter your Instagram username",
                                                                              style: Theme.of(context).textTheme.headline4,
                                                                            ),
                                                                            Container(
                                                                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(500), color: Theme.of(context).hintColor),
                                                                              child: TextField(
                                                                                cursorColor: config.Colors().mainAccentColor(1),
                                                                                style: Theme.of(context).textTheme.headline5.copyWith(color: Theme.of(context).accentColor),
                                                                                controller: _igController,
                                                                                decoration: InputDecoration(
                                                                                  contentPadding: const EdgeInsets.only(left: 30, top: 15),
                                                                                  border: InputBorder.none,
                                                                                  disabledBorder: InputBorder.none,
                                                                                  enabledBorder: InputBorder.none,
                                                                                  focusedBorder: InputBorder.none,
                                                                                  hintText: "Ex - PrismWallpapers",
                                                                                  hintStyle: Theme.of(context).textTheme.headline5.copyWith(fontSize: 14, color: Theme.of(context).accentColor),
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
                                                                    actions: <
                                                                        Widget>[
                                                                      FlatButton(
                                                                        shape: RoundedRectangleBorder(
                                                                            borderRadius:
                                                                                BorderRadius.circular(5)),
                                                                        onPressed:
                                                                            () {
                                                                          Navigator.of(context)
                                                                              .pop();
                                                                        },
                                                                        child:
                                                                            Text(
                                                                          'CANCEL',
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                16.0,
                                                                            color:
                                                                                config.Colors().mainAccentColor(1),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      Padding(
                                                                        padding:
                                                                            const EdgeInsets.only(right: 8.0),
                                                                        child:
                                                                            FlatButton(
                                                                          shape:
                                                                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                                                          color:
                                                                              config.Colors().mainAccentColor(1),
                                                                          onPressed:
                                                                              () async {
                                                                            Navigator.of(context).pop();
                                                                            await setUserIG("https://www.instagram.com/${_igController.text}",
                                                                                main.prefs.get("id").toString());
                                                                            toasts.codeSend("Successfully linked!");
                                                                          },
                                                                          child:
                                                                              const Text(
                                                                            'SAVE',
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 16.0,
                                                                              color: Colors.white,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                    backgroundColor:
                                                                        Theme.of(context)
                                                                            .primaryColor,
                                                                  ),
                                                                );
                                                              })
                                                  ],
                                                ),
                                              ),
                                              TableCell(
                                                verticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  children: <Widget>[
                                                    Row(
                                                      children: <Widget>[
                                                        Text(
                                                          "${favCount.toString()} ",
                                                          style: TextStyle(
                                                              fontFamily:
                                                                  "Proxima Nova",
                                                              fontSize: 24,
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal),
                                                        ),
                                                        Icon(
                                                          JamIcons.heart_f,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                        ),
                                                      ],
                                                    ),
                                                    Row(
                                                      children: <Widget>[
                                                        FutureBuilder(
                                                            future: Provider.of<
                                                                        ProfileWallProvider>(
                                                                    context,
                                                                    listen:
                                                                        false)
                                                                .getProfileWallsLength(),
                                                            builder: (context,
                                                                snapshot) {
                                                              return Text(
                                                                snapshot.data ==
                                                                        null
                                                                    ? "${profileCount.toString()} "
                                                                    : "${snapshot.data.toString()} ",
                                                                style: TextStyle(
                                                                    fontFamily:
                                                                        "Proxima Nova",
                                                                    fontSize:
                                                                        24,
                                                                    color: Theme.of(
                                                                            context)
                                                                        .accentColor,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .normal),
                                                              );
                                                            }),
                                                        Icon(
                                                          JamIcons.upload,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ]),
                                          ],
                                        ),
                                        // const Spacer(),
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
                                color: config.Colors().mainAccentColor(1),
                                child: SizedBox.expand(
                                  child: TabBar(
                                      indicatorColor:
                                          Theme.of(context).accentColor,
                                      indicatorSize: TabBarIndicatorSize.label,
                                      unselectedLabelColor:
                                          const Color(0xFFFFFFFF)
                                              .withOpacity(0.5),
                                      labelColor: const Color(0xFFFFFFFF),
                                      tabs: [
                                        Text(
                                          "Wallpapers",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .accentColor),
                                        ),
                                        Text(
                                          "Setups",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .accentColor),
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
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: ConfettiWidget(
                        confettiController: _controllerBottomCenter,
                        blastDirection: -pi / 2,
                        emissionFrequency: 0.05,
                        numberOfParticles: 20,
                        maxBlastForce: 100,
                        minBlastForce: 80,
                        gravity: 0.1,
                        colors: const [
                          Colors.green,
                          Colors.blue,
                          Colors.pink,
                          Colors.orange,
                          Colors.purple
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: ConfettiWidget(
                        confettiController: _controllerBottomCenter,
                        blastDirection: -pi / 3,
                        emissionFrequency: 0.05,
                        maxBlastForce: 100,
                        minBlastForce: 80,
                        gravity: 0.1,
                        colors: const [
                          Colors.green,
                          Colors.teal,
                          Colors.pink,
                          Colors.red,
                          Colors.purple
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ConfettiWidget(
                        confettiController: _controllerBottomCenter,
                        blastDirection: -2 * pi / 3,
                        emissionFrequency: 0.05,
                        maxBlastForce: 100,
                        minBlastForce: 80,
                        gravity: 0.1,
                        colors: const [
                          Colors.indigo,
                          Colors.blue,
                          Colors.pink,
                          Colors.deepOrange,
                          Colors.purple
                        ],
                      ),
                    ),
                  ],
                ))
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
                    const GeneralList(
                      expanded: false,
                    ),
                    UserList(
                      expanded: false,
                    ),
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
