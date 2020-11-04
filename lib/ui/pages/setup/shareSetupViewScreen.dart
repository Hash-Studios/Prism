import 'dart:ui';

import 'package:Prism/data/setups/provider/setupProvider.dart' as sdata;
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/menuButton/downloadButton.dart';
import 'package:Prism/ui/widgets/menuButton/setWallpaperButton.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/theme/config.dart' as config;
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/global/globals.dart' as globals;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:Prism/global/svgAssets.dart';

class ShareSetupViewScreen extends StatefulWidget {
  final List arguments;
  const ShareSetupViewScreen({this.arguments});

  @override
  _ShareSetupViewScreenState createState() => _ShareSetupViewScreenState();
}

class _ShareSetupViewScreenState extends State<ShareSetupViewScreen>
    with SingleTickerProviderStateMixin {
  Future<bool> onWillPop() async {
    navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String name;
  String image;
  Future<Map> _future;
  bool isLoading = true;
  List<Color> colors;
  PanelController panelController = PanelController();
  AnimationController shakeController;
  bool panelCollapsed = true;

  @override
  void initState() {
    shakeController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    name = widget.arguments[0].toString();
    image = widget.arguments[1].toString();
    _future = sdata.getSetupFromName(name);
    isLoading = true;
    super.initState();
    SystemChrome.setEnabledSystemUIOverlays([]);
  }

  // getData() async {
  //   await sdata.getSetupFromName(name).then((value) {
  //     setState(() {});
  //   });
  // }

  @override
  void dispose() {
    shakeController.dispose();
    super.dispose();
    SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.top, SystemUiOverlay.bottom]);
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> offsetAnimation = Tween(begin: 0.0, end: 48.0)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(shakeController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              shakeController.reverse();
            }
          });
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        resizeToAvoidBottomPadding: false,
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).primaryColor,
        body: FutureBuilder(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
            debugPrint(snapshot.connectionState.toString());
            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
                return Center(child: Loader());
              case ConnectionState.none:
                return Center(child: Loader());
              case ConnectionState.active:
                return Center(child: Loader());
              case ConnectionState.done:
                if (snapshot.hasError) {
                  return Center(child: Loader());
                } else {
                  return SlidingUpPanel(
                    backdropEnabled: true,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: const [],
                    collapsed: CollapsedPanel(panelCollapsed: panelCollapsed),
                    minHeight: MediaQuery.of(context).size.height / 20,
                    parallaxEnabled: true,
                    parallaxOffset: 0.00,
                    color: Colors.transparent,
                    maxHeight: MediaQuery.of(context).size.height * .43,
                    controller: panelController,
                    onPanelOpened: () {
                      setState(() {
                        panelCollapsed = false;
                      });
                    },
                    onPanelClosed: () {
                      setState(() {
                        panelCollapsed = true;
                      });
                    },
                    panel: Container(
                      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      height: MediaQuery.of(context).size.height * .43,
                      width: MediaQuery.of(context).size.width,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 750),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: panelCollapsed
                                  ? Theme.of(context)
                                      .primaryColor
                                      .withOpacity(1)
                                  : Theme.of(context)
                                      .primaryColor
                                      .withOpacity(.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Center(
                                    child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: AnimatedOpacity(
                                    duration: const Duration(),
                                    opacity: panelCollapsed ? 0.0 : 1.0,
                                    child: Icon(
                                      JamIcons.chevron_down,
                                      color: Theme.of(context).accentColor,
                                    ),
                                  ),
                                )),
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            35, 0, 35, 5),
                                        child: Text(
                                          name.toString().toUpperCase(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .headline1
                                              .copyWith(
                                                  fontSize: 30,
                                                  color: Theme.of(context)
                                                      .accentColor),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            35, 0, 35, 0),
                                        child: Text(
                                          sdata.setup["desc"].toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .headline6
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .accentColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 6,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        35, 0, 35, 10),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: <Widget>[
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      0, 5, 0, 10),
                                              child: Text(
                                                sdata.setup["id"]
                                                    .toString()
                                                    .toUpperCase(),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyText1
                                                    .copyWith(
                                                        color: Theme.of(context)
                                                            .accentColor),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Icon(
                                                  JamIcons.google_play_circle,
                                                  size: 20,
                                                  color: Theme.of(context)
                                                      .accentColor
                                                      .withOpacity(.7),
                                                ),
                                                const SizedBox(width: 10),
                                                Container(
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.32,
                                                  child: Text(
                                                    sdata.setup["icon"]
                                                        .toString(),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyText2
                                                        .copyWith(
                                                            color: Theme.of(
                                                                    context)
                                                                .accentColor),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(
                                              height: 5,
                                            ),
                                            Row(
                                              children: [
                                                sdata.setup["widget"] == ""
                                                    ? Container()
                                                    : Icon(
                                                        JamIcons.google_play,
                                                        size: 20,
                                                        color: Theme.of(context)
                                                            .accentColor
                                                            .withOpacity(.7),
                                                      ),
                                                const SizedBox(width: 10),
                                                Container(
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.32,
                                                  child: Text(
                                                    sdata.setup["widget"]
                                                        .toString(),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyText2
                                                        .copyWith(
                                                            color: Theme.of(
                                                                    context)
                                                                .accentColor),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: <Widget>[
                                            SizedBox(
                                              width: 159,
                                              child: Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Stack(
                                                  children: [
                                                    Align(
                                                      alignment:
                                                          Alignment.topRight,
                                                      child: ActionChip(
                                                          label: Text(
                                                            sdata.setup["by"]
                                                                .toString(),
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodyText2
                                                                .copyWith(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .accentColor),
                                                            overflow:
                                                                TextOverflow
                                                                    .fade,
                                                          ),
                                                          padding:
                                                              const EdgeInsets
                                                                      .symmetric(
                                                                  vertical: 5,
                                                                  horizontal:
                                                                      5),
                                                          avatar: CircleAvatar(
                                                            backgroundImage:
                                                                CachedNetworkImageProvider(sdata
                                                                    .setup[
                                                                        "userPhoto"]
                                                                    .toString()),
                                                          ),
                                                          labelPadding:
                                                              const EdgeInsets
                                                                      .fromLTRB(
                                                                  7, 3, 7, 3),
                                                          onPressed: () {
                                                            SystemChrome
                                                                .setEnabledSystemUIOverlays([
                                                              SystemUiOverlay
                                                                  .top,
                                                              SystemUiOverlay
                                                                  .bottom
                                                            ]);
                                                            Navigator.pushNamed(
                                                                context,
                                                                photographerProfileRoute,
                                                                arguments: [
                                                                  sdata.setup[
                                                                      "by"],
                                                                  sdata.setup[
                                                                      "email"],
                                                                  sdata.setup[
                                                                      "userPhoto"],
                                                                  false,
                                                                  sdata.setup["twitter"] !=
                                                                          null
                                                                      ? sdata
                                                                          .setup[
                                                                              "twitter"]
                                                                          .toString()
                                                                          .split(
                                                                              "https://www.twitter.com/")[1]
                                                                      : "",
                                                                  sdata.setup["instagram"] !=
                                                                          null
                                                                      ? sdata
                                                                          .setup[
                                                                              "instagram"]
                                                                          .toString()
                                                                          .split(
                                                                              "https://www.instagram.com/")[1]
                                                                      : "",
                                                                ]);
                                                          }),
                                                    ),
                                                    globals.verifiedUsers
                                                            .contains(sdata
                                                                .setup["email"]
                                                                .toString())
                                                        ? Align(
                                                            alignment: Alignment
                                                                .topRight,
                                                            child: Container(
                                                              width: 20,
                                                              height: 20,
                                                              child: SvgPicture.string(verifiedIcon.replaceAll(
                                                                  "E57697",
                                                                  config.Colors().mainAccentColor(
                                                                              1) ==
                                                                          Colors
                                                                              .black
                                                                      ? "E57697"
                                                                      : main
                                                                          .prefs
                                                                          .get(
                                                                              "mainAccentColor")
                                                                          .toRadixString(
                                                                              16)
                                                                          .toString()
                                                                          .substring(
                                                                              2))),
                                                            ),
                                                          )
                                                        : Container(),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                Text(
                                                  sdata.setup[
                                                          "wallpaper_provider"]
                                                      .toString(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyText2
                                                      .copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor),
                                                ),
                                                const SizedBox(width: 10),
                                                Icon(
                                                  JamIcons.database,
                                                  size: 20,
                                                  color: Theme.of(context)
                                                      .accentColor
                                                      .withOpacity(.7),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                main.prefs.get('premium') == true
                                    ? sdata.setup["widget"] == "" ||
                                            sdata.setup["widget"] == null
                                        ? sdata.setup["widget2"] == "" ||
                                                sdata.setup["widget2"] == null
                                            ? Expanded(
                                                flex: 5,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  children: [
                                                    ModifiedShareDownloadButton(),
                                                    ModifiedShareSetWallpaperButton(),
                                                    GestureDetector(
                                                      onTap: () async {
                                                        launch(sdata
                                                            .setup["icon_url"]
                                                            .toString());
                                                      },
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Theme.of(context)
                                                                  .primaryColor,
                                                          boxShadow: [
                                                            BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        .25),
                                                                blurRadius: 4,
                                                                offset:
                                                                    const Offset(
                                                                        0, 4))
                                                          ],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      500),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(17),
                                                        child: Icon(
                                                          JamIcons
                                                              .google_play_circle,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                          size: 20,
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              )
                                            : Expanded(
                                                flex: 5,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  children: <Widget>[
                                                    ModifiedShareDownloadButton(),
                                                    ModifiedShareSetWallpaperButton(),
                                                    GestureDetector(
                                                      onTap: () async {
                                                        launch(sdata
                                                            .setup["icon_url"]
                                                            .toString());
                                                      },
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Theme.of(context)
                                                                  .primaryColor,
                                                          boxShadow: [
                                                            BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        .25),
                                                                blurRadius: 4,
                                                                offset:
                                                                    const Offset(
                                                                        0, 4))
                                                          ],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      500),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(17),
                                                        child: Icon(
                                                          JamIcons
                                                              .google_play_circle,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                          size: 20,
                                                        ),
                                                      ),
                                                    ),
                                                    GestureDetector(
                                                      onTap: () async {
                                                        launch(sdata.setup[
                                                                "widget_url2"]
                                                            .toString());
                                                      },
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Theme.of(context)
                                                                  .primaryColor,
                                                          boxShadow: [
                                                            BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        .25),
                                                                blurRadius: 4,
                                                                offset:
                                                                    const Offset(
                                                                        0, 4))
                                                          ],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      500),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(17),
                                                        child: Icon(
                                                          JamIcons.google_play,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                          size: 20,
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              )
                                        : sdata.setup["widget2"] == "" ||
                                                sdata.setup["widget2"] == null
                                            ? Expanded(
                                                flex: 5,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  children: <Widget>[
                                                    ModifiedShareDownloadButton(),
                                                    ModifiedShareSetWallpaperButton(),
                                                    GestureDetector(
                                                      onTap: () async {
                                                        launch(sdata
                                                            .setup["icon_url"]
                                                            .toString());
                                                      },
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Theme.of(context)
                                                                  .primaryColor,
                                                          boxShadow: [
                                                            BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        .25),
                                                                blurRadius: 4,
                                                                offset:
                                                                    const Offset(
                                                                        0, 4))
                                                          ],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      500),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(17),
                                                        child: Icon(
                                                          JamIcons
                                                              .google_play_circle,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                          size: 20,
                                                        ),
                                                      ),
                                                    ),
                                                    GestureDetector(
                                                      onTap: () async {
                                                        launch(sdata
                                                            .setup["widget_url"]
                                                            .toString());
                                                      },
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Theme.of(context)
                                                                  .primaryColor,
                                                          boxShadow: [
                                                            BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        .25),
                                                                blurRadius: 4,
                                                                offset:
                                                                    const Offset(
                                                                        0, 4))
                                                          ],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      500),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(17),
                                                        child: Icon(
                                                          JamIcons.google_play,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                          size: 20,
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              )
                                            : Expanded(
                                                flex: 5,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  children: <Widget>[
                                                    ModifiedShareDownloadButton(),
                                                    ModifiedShareSetWallpaperButton(),
                                                    GestureDetector(
                                                      onTap: () async {
                                                        launch(sdata
                                                            .setup["icon_url"]
                                                            .toString());
                                                      },
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Theme.of(context)
                                                                  .primaryColor,
                                                          boxShadow: [
                                                            BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        .25),
                                                                blurRadius: 4,
                                                                offset:
                                                                    const Offset(
                                                                        0, 4))
                                                          ],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      500),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(17),
                                                        child: Icon(
                                                          JamIcons
                                                              .google_play_circle,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                          size: 20,
                                                        ),
                                                      ),
                                                    ),
                                                    GestureDetector(
                                                      onTap: () async {
                                                        launch(sdata
                                                            .setup["widget_url"]
                                                            .toString());
                                                      },
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Theme.of(context)
                                                                  .primaryColor,
                                                          boxShadow: [
                                                            BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        .25),
                                                                blurRadius: 4,
                                                                offset:
                                                                    const Offset(
                                                                        0, 4))
                                                          ],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      500),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(17),
                                                        child: Icon(
                                                          JamIcons.google_play,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                          size: 20,
                                                        ),
                                                      ),
                                                    ),
                                                    GestureDetector(
                                                      onTap: () async {
                                                        launch(sdata.setup[
                                                                "widget_url2"]
                                                            .toString());
                                                      },
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Theme.of(context)
                                                                  .primaryColor,
                                                          boxShadow: [
                                                            BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        .25),
                                                                blurRadius: 4,
                                                                offset:
                                                                    const Offset(
                                                                        0, 4))
                                                          ],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      500),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(17),
                                                        child: Icon(
                                                          JamIcons.google_play,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                          size: 20,
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              )
                                    : Expanded(
                                        flex: 5,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            GestureDetector(
                                              onTap: () async {
                                                toasts.codeSend(
                                                    "Applying Setups require Premium");
                                                void showGooglePopUp(
                                                    Function func) {
                                                  debugPrint(main.prefs
                                                      .get("isLoggedin")
                                                      .toString());
                                                  if (main.prefs
                                                          .get("isLoggedin") ==
                                                      false) {
                                                    googleSignInPopUp(
                                                        context, func);
                                                  } else {
                                                    func();
                                                  }
                                                }

                                                showGooglePopUp(() {
                                                  if (main.prefs
                                                          .get('premium') !=
                                                      true) {
                                                    Navigator.pushNamed(
                                                        context, premiumRoute);
                                                  }
                                                });
                                              },
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .primaryColor,
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(.25),
                                                        blurRadius: 4,
                                                        offset:
                                                            const Offset(0, 4))
                                                  ],
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          500),
                                                ),
                                                padding:
                                                    const EdgeInsets.all(17),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      JamIcons.stop_sign,
                                                      color: Theme.of(context)
                                                          .accentColor,
                                                      size: 30,
                                                    ),
                                                    const SizedBox(
                                                      width: 4,
                                                    ),
                                                    Text(
                                                      "Premium Required",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .headline4
                                                          .copyWith(
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    body: Stack(
                      children: <Widget>[
                        AnimatedBuilder(
                            animation: offsetAnimation,
                            builder: (buildContext, child) {
                              if (offsetAnimation.value < 0.0) {
                                debugPrint('${offsetAnimation.value + 8.0}');
                              }
                              return GestureDetector(
                                onPanUpdate: (details) {
                                  if (details.delta.dy < -10) {
                                    panelController.open();
                                    // HapticFeedback.vibrate();
                                  }
                                },
                                onLongPress: () {
                                  HapticFeedback.vibrate();
                                  shakeController.forward(from: 0.0);
                                },
                                onTap: () {
                                  HapticFeedback.vibrate();
                                  shakeController.forward(from: 0.0);
                                },
                                child: CachedNetworkImage(
                                  imageUrl: image,
                                  imageBuilder: (context, imageProvider) =>
                                      Hero(
                                    tag: "CustomHerotag$name",
                                    child: Container(
                                      margin: EdgeInsets.symmetric(
                                          vertical:
                                              offsetAnimation.value * 1.25,
                                          horizontal:
                                              offsetAnimation.value / 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                            offsetAnimation.value),
                                        image: DecorationImage(
                                          image: imageProvider,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  progressIndicatorBuilder:
                                      (context, url, downloadProgress) => Stack(
                                    children: <Widget>[
                                      const SizedBox.expand(child: Text("")),
                                      Center(
                                        child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation(
                                              config.Colors()
                                                  .mainAccentColor(1),
                                            ),
                                            value: downloadProgress.progress),
                                      ),
                                    ],
                                  ),
                                  errorWidget: (context, url, error) => Center(
                                    child: Icon(
                                      JamIcons.close_circle_f,
                                      color: isLoading
                                          ? Theme.of(context).accentColor
                                          : colors[0].computeLuminance() > 0.5
                                              ? Colors.black
                                              : Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            }),
                        Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: IconButton(
                              onPressed: () {
                                navStack.removeLast();
                                debugPrint(navStack.toString());
                                Navigator.pop(context);
                              },
                              color: isLoading
                                  ? Theme.of(context).accentColor
                                  : colors[0].computeLuminance() > 0.5
                                      ? Colors.black
                                      : Colors.white,
                              icon: const Icon(
                                JamIcons.chevron_left,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                break;
              default:
                return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}

class ModifiedShareDownloadButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return sdata.setup["wallpaper_url"].toString()[0] != "["
        ? DownloadButton(
            link: sdata.setup["wallpaper_url"].toString(),
            colorChanged: false,
          )
        : GestureDetector(
            onTap: () async {
              launch(sdata.setup["wallpaper_url"][1].toString());
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(.25),
                      blurRadius: 4,
                      offset: const Offset(0, 4))
                ],
                borderRadius: BorderRadius.circular(500),
              ),
              padding: const EdgeInsets.all(17),
              child: Icon(
                JamIcons.download,
                color: Theme.of(context).accentColor,
                size: 20,
              ),
            ),
          );
  }
}

class ModifiedShareSetWallpaperButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return sdata.setup["wallpaper_url"].toString()[0] != "["
        ? SetWallpaperButton(
            url: sdata.setup["wallpaper_url"].toString(),
            colorChanged: false,
          )
        : GestureDetector(
            onTap: () async {
              launch(sdata.setup["wallpaper_url"][1].toString());
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(.25),
                      blurRadius: 4,
                      offset: const Offset(0, 4))
                ],
                borderRadius: BorderRadius.circular(500),
              ),
              padding: const EdgeInsets.all(17),
              child: Icon(
                JamIcons.picture,
                color: Theme.of(context).accentColor,
                size: 20,
              ),
            ),
          );
  }
}

class CollapsedPanel extends StatelessWidget {
  final bool panelCollapsed;
  const CollapsedPanel({
    Key key,
    this.panelCollapsed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 750),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        color: panelCollapsed
            ? Theme.of(context).primaryColor.withOpacity(1)
            : Theme.of(context).primaryColor.withOpacity(0),
      ),
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height / 30,
        child: Center(
            child: AnimatedOpacity(
          duration: const Duration(),
          opacity: panelCollapsed ? 1.0 : 0.0,
          child: Icon(
            JamIcons.chevron_up,
            color: Theme.of(context).accentColor,
          ),
        )),
      ),
    );
  }
}
