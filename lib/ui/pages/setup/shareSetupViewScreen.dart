import 'dart:ui';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/data/favourites/provider/favouriteSetupProvider.dart';
import 'package:Prism/data/informatics/dataManager.dart';
import 'package:Prism/data/setups/provider/setupProvider.dart' as sdata;
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/ui/widgets/animated/favouriteIcon.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/animated/showUp.dart';
import 'package:Prism/ui/widgets/home/core/collapsedPanel.dart';
import 'package:Prism/ui/widgets/home/wallpapers/clockSetupOverlay.dart';
import 'package:Prism/ui/widgets/menuButton/downloadButton.dart';
import 'package:Prism/ui/widgets/menuButton/setWallpaperButton.dart';
import 'package:Prism/ui/widgets/popup/copyrightPopUp.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:animations/animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareSetupViewScreen extends StatefulWidget {
  final List? arguments;
  const ShareSetupViewScreen({this.arguments});

  @override
  _ShareSetupViewScreenState createState() => _ShareSetupViewScreenState();
}

class _ShareSetupViewScreenState extends State<ShareSetupViewScreen>
    with SingleTickerProviderStateMixin {
  Future<bool> onWillPop() async {
    navStack.removeLast();
    logger.d(navStack.toString());
    return true;
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? name;
  String? image;
  Future<Map?>? _future;
  bool isLoading = true;
  List<Color>? colors;
  PanelController panelController = PanelController();
  late AnimationController shakeController;
  bool panelCollapsed = true;
  bool? viewCounted;
  Future<String>? _futureView;
  late Box box;

  @override
  void initState() {
    viewCounted = false;
    shakeController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    name = widget.arguments![0].toString();
    image = widget.arguments![1].toString();
    _future = sdata.getSetupFromName(name);
    isLoading = true;
    box = Hive.box('localFav');
    super.initState();
  }

  @override
  void dispose() {
    shakeController.dispose();
    super.dispose();
  }

  Future<void> onFavSetup(String id, Map? setupMap) async {
    setState(() {
      isLoading = true;
    });
    Provider.of<FavouriteSetupProvider>(context, listen: false)
        .favCheck(id, setupMap)
        .then((value) {
      analytics.logEvent(name: 'setup_fav_status_changed', parameters: {
        'id': id,
      });
      setState(() {
        isLoading = false;
      });
    });
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
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).primaryColor,
        body: FutureBuilder(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<Map?> snapshot) {
            logger.d(snapshot.connectionState.toString());
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
                  if (viewCounted == false) {
                    updateViewsSetup(
                        sdata.setup!["id"].toString().toUpperCase());
                    _futureView = getViewsSetup(
                        sdata.setup!["id"].toString().toUpperCase());
                    viewCounted = true;
                  }
                  return SlidingUpPanel(
                    backdropEnabled: true,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: const [],
                    collapsed: CollapsedPanel(
                      panelCollapsed: panelCollapsed,
                      panelController: panelController,
                    ),
                    minHeight: MediaQuery.of(context).size.height / 20,
                    parallaxEnabled: true,
                    parallaxOffset: 0.00,
                    color: Colors.transparent,
                    maxHeight: globals.prismUser.premium == true
                        ? MediaQuery.of(context).size.height * .70 > 600
                            ? MediaQuery.of(context).size.height * .70
                            : 600
                        : 300,
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
                      height: globals.prismUser.premium == true
                          ? MediaQuery.of(context).size.height * .70 > 600
                              ? MediaQuery.of(context).size.height * .70
                              : 600
                          : 300,
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
                                    child: GestureDetector(
                                      onTap: () {
                                        panelController.close();
                                      },
                                      child: Icon(
                                        JamIcons.chevron_down,
                                        color: Theme.of(context).accentColor,
                                      ),
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
                                        child: panelCollapsed
                                            ? Container()
                                            : ShowUpTransition(
                                                forward: true,
                                                slideSide:
                                                    SlideFromSlide.bottom,
                                                child: Text(
                                                  sdata.setup!["name"]
                                                      .toString()
                                                      .toUpperCase(),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.fade,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headline1!
                                                      .copyWith(
                                                          fontSize: 30,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor),
                                                ),
                                              ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            35, 0, 35, 0),
                                        child: panelCollapsed
                                            ? Container()
                                            : ShowUpTransition(
                                                forward: true,
                                                slideSide:
                                                    SlideFromSlide.bottom,
                                                delay: const Duration(
                                                    milliseconds: 50),
                                                child: Text(
                                                  sdata.setup!["desc"]
                                                      .toString(),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.fade,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headline6!
                                                      .copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor),
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        35, 0, 35, 10),
                                    child: panelCollapsed
                                        ? Container()
                                        : ShowUpTransition(
                                            forward: true,
                                            delay: const Duration(
                                                milliseconds: 100),
                                            slideSide: SlideFromSlide.bottom,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: <Widget>[
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: <Widget>[
                                                    SizedBox(
                                                      width:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .width *
                                                              0.36,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                    .fromLTRB(
                                                                0, 5, 0, 5),
                                                        child: Row(
                                                          children: [
                                                            Text(
                                                              sdata.setup!["id"]
                                                                  .toString()
                                                                  .toUpperCase(),
                                                              overflow:
                                                                  TextOverflow
                                                                      .fade,
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodyText1!
                                                                  .copyWith(
                                                                      color: Theme.of(
                                                                              context)
                                                                          .accentColor,
                                                                      fontSize:
                                                                          16),
                                                            ),
                                                            Padding(
                                                              padding: const EdgeInsets
                                                                      .symmetric(
                                                                  horizontal:
                                                                      6.0),
                                                              child: Container(
                                                                height: 16,
                                                                color: Theme.of(
                                                                        context)
                                                                    .accentColor,
                                                                width: 2,
                                                              ),
                                                            ),
                                                            FutureBuilder(
                                                              future:
                                                                  _futureView,
                                                              builder: (context,
                                                                  snapshot) {
                                                                switch (snapshot
                                                                    .connectionState) {
                                                                  case ConnectionState
                                                                      .waiting:
                                                                    return Text(
                                                                      "",
                                                                      style: Theme.of(
                                                                              context)
                                                                          .textTheme
                                                                          .bodyText1!
                                                                          .copyWith(
                                                                              color: Theme.of(context).accentColor,
                                                                              fontSize: 16),
                                                                    );
                                                                  case ConnectionState
                                                                      .none:
                                                                    return Text(
                                                                      "",
                                                                      style: Theme.of(
                                                                              context)
                                                                          .textTheme
                                                                          .bodyText1!
                                                                          .copyWith(
                                                                              color: Theme.of(context).accentColor,
                                                                              fontSize: 16),
                                                                    );
                                                                  default:
                                                                    if (snapshot
                                                                        .hasError) {
                                                                      return Text(
                                                                        "",
                                                                        style: Theme.of(context)
                                                                            .textTheme
                                                                            .bodyText1!
                                                                            .copyWith(
                                                                                color: Theme.of(context).accentColor,
                                                                                fontSize: 16),
                                                                      );
                                                                    } else {
                                                                      return Text(
                                                                        "${snapshot.data} views",
                                                                        overflow:
                                                                            TextOverflow.fade,
                                                                        softWrap:
                                                                            false,
                                                                        style: Theme.of(context)
                                                                            .textTheme
                                                                            .bodyText1!
                                                                            .copyWith(
                                                                                color: Theme.of(context).accentColor,
                                                                                fontSize: 16),
                                                                      );
                                                                    }
                                                                }
                                                              },
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    GestureDetector(
                                                      onTap: () {
                                                        showModal(
                                                            context: context,
                                                            configuration:
                                                                const FadeScaleTransitionConfiguration(),
                                                            builder: (BuildContext
                                                                    context) =>
                                                                CopyrightPopUp(
                                                                  setup: true,
                                                                  shortlink:
                                                                      "Setup ID - ${sdata.setup!["id"]}",
                                                                ));
                                                      },
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            JamIcons.info,
                                                            size: 20,
                                                            color: Theme.of(
                                                                    context)
                                                                .accentColor
                                                                .withOpacity(
                                                                    .7),
                                                          ),
                                                          const SizedBox(
                                                              width: 10),
                                                          Text(
                                                            "Report",
                                                            overflow:
                                                                TextOverflow
                                                                    .fade,
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodyText2!
                                                                .copyWith(
                                                                    decoration:
                                                                        TextDecoration
                                                                            .underline,
                                                                    color: Theme.of(
                                                                            context)
                                                                        .accentColor),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: <Widget>[
                                                    SizedBox(
                                                      width: 150,
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: Stack(
                                                          children: [
                                                            Align(
                                                              alignment:
                                                                  Alignment
                                                                      .topRight,
                                                              child: ActionChip(
                                                                  label: Text(
                                                                    sdata
                                                                        .setup![
                                                                            "by"]
                                                                        .toString(),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .fade,
                                                                    style: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .bodyText2!
                                                                        .copyWith(
                                                                            color:
                                                                                Theme.of(context).accentColor),
                                                                  ),
                                                                  padding: const EdgeInsets
                                                                          .symmetric(
                                                                      vertical:
                                                                          5,
                                                                      horizontal:
                                                                          5),
                                                                  avatar:
                                                                      CircleAvatar(
                                                                    backgroundImage: CachedNetworkImageProvider(sdata
                                                                        .setup![
                                                                            "userPhoto"]
                                                                        .toString()),
                                                                  ),
                                                                  labelPadding:
                                                                      const EdgeInsets
                                                                              .fromLTRB(
                                                                          7,
                                                                          3,
                                                                          7,
                                                                          3),
                                                                  onPressed:
                                                                      () {
                                                                    Navigator.pushNamed(
                                                                        context,
                                                                        followerProfileRoute,
                                                                        arguments: [
                                                                          sdata.setup![
                                                                              "email"],
                                                                        ]);
                                                                  }),
                                                            ),
                                                            if (globals
                                                                .verifiedUsers
                                                                .contains(sdata
                                                                    .setup![
                                                                        "email"]
                                                                    .toString()))
                                                              Align(
                                                                alignment:
                                                                    Alignment
                                                                        .topRight,
                                                                child: SizedBox(
                                                                  width: 20,
                                                                  height: 20,
                                                                  child: SvgPicture.string(verifiedIcon.replaceAll(
                                                                      "E57697",
                                                                      Theme.of(context).errorColor ==
                                                                              Colors
                                                                                  .black
                                                                          ? "E57697"
                                                                          : Theme.of(context)
                                                                              .errorColor
                                                                              .toString()
                                                                              .replaceAll("Color(0xff", "")
                                                                              .replaceAll(")", ""))),
                                                                ),
                                                              )
                                                            else
                                                              Container(),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                ),
                                if (globals.prismUser.premium == true)
                                  Expanded(
                                    flex: 16,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          35, 0, 35, 0),
                                      child: sdata.setup!["widget"] == "" ||
                                              sdata.setup!["widget"] == null
                                          ? Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SetupDetailsTile(
                                                  isInstalled:
                                                      Future.value(false),
                                                  onTap: () async {
                                                    if (sdata.setup![
                                                                "wallpaper_url"]
                                                            .toString()[0] !=
                                                        "[") {
                                                      if (sdata.setup![
                                                                  "wall_id"] ==
                                                              null ||
                                                          sdata.setup![
                                                                  "wall_id"] ==
                                                              "") {
                                                        logger
                                                            .d("Id Not Found!");
                                                        launch(sdata.setup![
                                                                "wallpaper_url"]
                                                            .toString());
                                                      } else {
                                                        Navigator.pushNamed(
                                                            context, shareRoute,
                                                            arguments: [
                                                              sdata.setup![
                                                                      "wall_id"]
                                                                  .toString(),
                                                              sdata.setup![
                                                                      "wallpaper_provider"]
                                                                  .toString(),
                                                              sdata.setup![
                                                                      "wallpaper_url"]
                                                                  .toString(),
                                                              sdata.setup![
                                                                      "wallpaper_url"]
                                                                  .toString(),
                                                            ]);
                                                      }
                                                    } else {
                                                      launch(sdata.setup![
                                                              "wallpaper_url"]
                                                              [1]
                                                          .toString());
                                                    }
                                                  },
                                                  tileText: sdata.setup![
                                                                  "wallpaper_url"]
                                                              .toString()[0] !=
                                                          "["
                                                      ? (sdata.setup!["wall_id"] ==
                                                                  null ||
                                                              sdata.setup![
                                                                      "wall_id"] ==
                                                                  "")
                                                          ? "Wall Link"
                                                          : "Prism (${sdata.setup!["wall_id"]})"
                                                      : "${sdata.setup!["wallpaper_url"][0]} - ${(sdata.setup!["wallpaper_url"] as List).length > 2 ? sdata.setup!["wallpaper_url"][2].toString() : ""}",
                                                  tileType: "Wallpaper",
                                                  panelCollapsed:
                                                      panelCollapsed,
                                                  delay: const Duration(
                                                      milliseconds: 150),
                                                ),
                                                SetupDetailsTile(
                                                  isInstalled: sdata
                                                          .setup!["icon_url"]
                                                          .toString()
                                                          .contains(
                                                              'play.google.com/store/apps/details?id=')
                                                      ? DeviceApps
                                                          .isAppInstalled(sdata
                                                              .setup![
                                                                  "icon_url"]
                                                              .toString()
                                                              .split(
                                                                  "details?id=")[1]
                                                              .split("&")[0])
                                                      : Future.value(false),
                                                  onTap: () async {
                                                    if (sdata.setup!["icon_url"]
                                                        .toString()
                                                        .contains(
                                                            'play.google.com/store/apps/details?id=')) {
                                                      final isInstalled =
                                                          await DeviceApps
                                                              .isAppInstalled(sdata
                                                                  .setup![
                                                                      "icon_url"]
                                                                  .toString()
                                                                  .split("details?id=")[
                                                                      1]
                                                                  .split(
                                                                      "&")[0]);
                                                      isInstalled
                                                          ? DeviceApps.openApp(sdata
                                                              .setup![
                                                                  "icon_url"]
                                                              .toString()
                                                              .split("details?id=")[
                                                                  1]
                                                              .split("&")[0])
                                                          : launch(sdata.setup![
                                                                  "icon_url"]
                                                              .toString());
                                                    } else {
                                                      launch(sdata
                                                          .setup!["icon_url"]
                                                          .toString());
                                                    }
                                                  },
                                                  tileText: sdata.setup!["icon"]
                                                      .toString(),
                                                  tileType: "Icons",
                                                  panelCollapsed:
                                                      panelCollapsed,
                                                  delay: const Duration(
                                                      milliseconds: 200),
                                                ),
                                              ],
                                            )
                                          : sdata.setup!["widget2"] == "" ||
                                                  sdata.setup!["widget2"] ==
                                                      null
                                              ? Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    SetupDetailsTile(
                                                      isInstalled:
                                                          Future.value(false),
                                                      onTap: () async {
                                                        if (sdata.setup![
                                                                    "wallpaper_url"]
                                                                .toString()[0] !=
                                                            "[") {
                                                          if (sdata.setup![
                                                                      "wall_id"] ==
                                                                  null ||
                                                              sdata.setup![
                                                                      "wall_id"] ==
                                                                  "") {
                                                            logger.d(
                                                                "Id Not Found!");
                                                            launch(sdata.setup![
                                                                    "wallpaper_url"]
                                                                .toString());
                                                          } else {
                                                            Navigator.pushNamed(
                                                                context,
                                                                shareRoute,
                                                                arguments: [
                                                                  sdata.setup![
                                                                          "wall_id"]
                                                                      .toString(),
                                                                  sdata.setup![
                                                                          "wallpaper_provider"]
                                                                      .toString(),
                                                                  sdata.setup![
                                                                          "wallpaper_url"]
                                                                      .toString(),
                                                                  sdata.setup![
                                                                          "wallpaper_url"]
                                                                      .toString(),
                                                                ]);
                                                          }
                                                        } else {
                                                          launch(sdata.setup![
                                                                  "wallpaper_url"]
                                                                  [1]
                                                              .toString());
                                                        }
                                                      },
                                                      tileText: sdata.setup![
                                                                          "wallpaper_url"]
                                                                      .toString()[
                                                                  0] !=
                                                              "["
                                                          ? (sdata.setup!["wall_id"] ==
                                                                      null ||
                                                                  sdata.setup![
                                                                          "wall_id"] ==
                                                                      "")
                                                              ? "Wall Link"
                                                              : "Prism (${sdata.setup!["wall_id"]})"
                                                          : "${sdata.setup!["wallpaper_url"][0]} - ${(sdata.setup!["wallpaper_url"] as List).length > 2 ? sdata.setup!["wallpaper_url"][2].toString() : ""}",
                                                      tileType: "Wallpaper",
                                                      panelCollapsed:
                                                          panelCollapsed,
                                                      delay: const Duration(
                                                          milliseconds: 150),
                                                    ),
                                                    SetupDetailsTile(
                                                      isInstalled: sdata.setup![
                                                                  "icon_url"]
                                                              .toString()
                                                              .contains(
                                                                  'play.google.com/store/apps/details?id=')
                                                          ? DeviceApps.isAppInstalled(sdata
                                                              .setup![
                                                                  "icon_url"]
                                                              .toString()
                                                              .split(
                                                                  "details?id=")[1]
                                                              .split("&")[0])
                                                          : Future.value(false),
                                                      onTap: () async {
                                                        if (sdata
                                                            .setup!["icon_url"]
                                                            .toString()
                                                            .contains(
                                                                'play.google.com/store/apps/details?id=')) {
                                                          final isInstalled = await DeviceApps
                                                              .isAppInstalled(sdata
                                                                  .setup![
                                                                      "icon_url"]
                                                                  .toString()
                                                                  .split("details?id=")[
                                                                      1]
                                                                  .split(
                                                                      "&")[0]);
                                                          isInstalled
                                                              ? DeviceApps.openApp(sdata
                                                                  .setup![
                                                                      "icon_url"]
                                                                  .toString()
                                                                  .split("details?id=")[
                                                                      1]
                                                                  .split(
                                                                      "&")[0])
                                                              : launch(sdata
                                                                  .setup![
                                                                      "icon_url"]
                                                                  .toString());
                                                        } else {
                                                          launch(sdata.setup![
                                                                  "icon_url"]
                                                              .toString());
                                                        }
                                                      },
                                                      tileText: sdata
                                                          .setup!["icon"]
                                                          .toString(),
                                                      tileType: "Icons",
                                                      panelCollapsed:
                                                          panelCollapsed,
                                                      delay: const Duration(
                                                          milliseconds: 200),
                                                    ),
                                                    SetupDetailsTile(
                                                      isInstalled: sdata.setup![
                                                                  "widget_url"]
                                                              .toString()
                                                              .contains(
                                                                  'play.google.com/store/apps/details?id=')
                                                          ? DeviceApps.isAppInstalled(sdata
                                                              .setup![
                                                                  "widget_url"]
                                                              .toString()
                                                              .split(
                                                                  "details?id=")[1]
                                                              .split("&")[0])
                                                          : Future.value(false),
                                                      onTap: () async {
                                                        if (sdata.setup![
                                                                "widget_url"]
                                                            .toString()
                                                            .contains(
                                                                'play.google.com/store/apps/details?id=')) {
                                                          final isInstalled = await DeviceApps
                                                              .isAppInstalled(sdata
                                                                  .setup![
                                                                      "widget_url"]
                                                                  .toString()
                                                                  .split("details?id=")[
                                                                      1]
                                                                  .split(
                                                                      "&")[0]);
                                                          isInstalled
                                                              ? DeviceApps.openApp(sdata
                                                                  .setup![
                                                                      "widget_url"]
                                                                  .toString()
                                                                  .split("details?id=")[
                                                                      1]
                                                                  .split(
                                                                      "&")[0])
                                                              : launch(sdata
                                                                  .setup![
                                                                      "widget_url"]
                                                                  .toString());
                                                        } else {
                                                          launch(sdata.setup![
                                                                  "widget_url"]
                                                              .toString());
                                                        }
                                                      },
                                                      tileText: sdata
                                                          .setup!["widget"]
                                                          .toString(),
                                                      tileType: "Widget",
                                                      panelCollapsed:
                                                          panelCollapsed,
                                                      delay: const Duration(
                                                          milliseconds: 250),
                                                    ),
                                                  ],
                                                )
                                              : Scrollbar(
                                                  radius: const Radius.circular(
                                                      500),
                                                  thickness: 5,
                                                  child: ListView(
                                                    children: [
                                                      SetupDetailsTile(
                                                        isInstalled:
                                                            Future.value(false),
                                                        onTap: () async {
                                                          if (sdata.setup![
                                                                      "wallpaper_url"]
                                                                  .toString()[0] !=
                                                              "[") {
                                                            if (sdata.setup![
                                                                        "wall_id"] ==
                                                                    null ||
                                                                sdata.setup![
                                                                        "wall_id"] ==
                                                                    "") {
                                                              logger.d(
                                                                  "Id Not Found!");
                                                              launch(sdata
                                                                  .setup![
                                                                      "wallpaper_url"]
                                                                  .toString());
                                                            } else {
                                                              Navigator.pushNamed(
                                                                  context,
                                                                  shareRoute,
                                                                  arguments: [
                                                                    sdata
                                                                        .setup![
                                                                            "wall_id"]
                                                                        .toString(),
                                                                    sdata
                                                                        .setup![
                                                                            "wallpaper_provider"]
                                                                        .toString(),
                                                                    sdata
                                                                        .setup![
                                                                            "wallpaper_url"]
                                                                        .toString(),
                                                                    sdata
                                                                        .setup![
                                                                            "wallpaper_url"]
                                                                        .toString(),
                                                                  ]);
                                                            }
                                                          } else {
                                                            launch(sdata.setup![
                                                                    "wallpaper_url"]
                                                                    [1]
                                                                .toString());
                                                          }
                                                        },
                                                        tileText: sdata.setup![
                                                                            "wallpaper_url"]
                                                                        .toString()[
                                                                    0] !=
                                                                "["
                                                            ? (sdata.setup!["wall_id"] ==
                                                                        null ||
                                                                    sdata.setup![
                                                                            "wall_id"] ==
                                                                        "")
                                                                ? "Wall Link"
                                                                : "Prism (${sdata.setup!["wall_id"]})"
                                                            : "${sdata.setup!["wallpaper_url"][0]} - ${(sdata.setup!["wallpaper_url"] as List).length > 2 ? sdata.setup!["wallpaper_url"][2].toString() : ""}",
                                                        tileType: "Wallpaper",
                                                        panelCollapsed:
                                                            panelCollapsed,
                                                        delay: const Duration(
                                                            milliseconds: 150),
                                                      ),
                                                      SetupDetailsTile(
                                                        isInstalled: sdata
                                                                .setup![
                                                                    "icon_url"]
                                                                .toString()
                                                                .contains(
                                                                    'play.google.com/store/apps/details?id=')
                                                            ? DeviceApps
                                                                .isAppInstalled(sdata
                                                                    .setup![
                                                                        "icon_url"]
                                                                    .toString()
                                                                    .split("details?id=")[
                                                                        1]
                                                                    .split(
                                                                        "&")[0])
                                                            : Future.value(
                                                                false),
                                                        onTap: () async {
                                                          if (sdata.setup![
                                                                  "icon_url"]
                                                              .toString()
                                                              .contains(
                                                                  'play.google.com/store/apps/details?id=')) {
                                                            final isInstalled =
                                                                await DeviceApps.isAppInstalled(sdata
                                                                    .setup![
                                                                        "icon_url"]
                                                                    .toString()
                                                                    .split("details?id=")[
                                                                        1]
                                                                    .split(
                                                                        "&")[0]);
                                                            isInstalled
                                                                ? DeviceApps.openApp(sdata
                                                                    .setup![
                                                                        "icon_url"]
                                                                    .toString()
                                                                    .split("details?id=")[
                                                                        1]
                                                                    .split(
                                                                        "&")[0])
                                                                : launch(sdata
                                                                    .setup![
                                                                        "icon_url"]
                                                                    .toString());
                                                          } else {
                                                            launch(sdata.setup![
                                                                    "icon_url"]
                                                                .toString());
                                                          }
                                                        },
                                                        tileText: sdata
                                                            .setup!["icon"]
                                                            .toString(),
                                                        tileType: "Icons",
                                                        panelCollapsed:
                                                            panelCollapsed,
                                                        delay: const Duration(
                                                            milliseconds: 200),
                                                      ),
                                                      SetupDetailsTile(
                                                        isInstalled: sdata
                                                                .setup![
                                                                    "widget_url"]
                                                                .toString()
                                                                .contains(
                                                                    'play.google.com/store/apps/details?id=')
                                                            ? DeviceApps.isAppInstalled(sdata
                                                                .setup![
                                                                    "widget_url"]
                                                                .toString()
                                                                .split("details?id=")[
                                                                    1]
                                                                .split("&")[0])
                                                            : Future.value(
                                                                false),
                                                        onTap: () async {
                                                          if (sdata.setup![
                                                                  "widget_url"]
                                                              .toString()
                                                              .contains(
                                                                  'play.google.com/store/apps/details?id=')) {
                                                            final isInstalled =
                                                                await DeviceApps.isAppInstalled(sdata
                                                                    .setup![
                                                                        "widget_url"]
                                                                    .toString()
                                                                    .split("details?id=")[
                                                                        1]
                                                                    .split(
                                                                        "&")[0]);
                                                            isInstalled
                                                                ? DeviceApps.openApp(sdata
                                                                    .setup![
                                                                        "widget_url"]
                                                                    .toString()
                                                                    .split("details?id=")[
                                                                        1]
                                                                    .split(
                                                                        "&")[0])
                                                                : launch(sdata
                                                                    .setup![
                                                                        "widget_url"]
                                                                    .toString());
                                                          } else {
                                                            launch(sdata.setup![
                                                                    "widget_url"]
                                                                .toString());
                                                          }
                                                        },
                                                        tileText: sdata
                                                            .setup!["widget"]
                                                            .toString(),
                                                        tileType: "Widget",
                                                        panelCollapsed:
                                                            panelCollapsed,
                                                        delay: const Duration(
                                                            milliseconds: 250),
                                                      ),
                                                      SetupDetailsTile(
                                                        isInstalled: sdata
                                                                .setup![
                                                                    "widget_url2"]
                                                                .toString()
                                                                .contains(
                                                                    'play.google.com/store/apps/details?id=')
                                                            ? DeviceApps.isAppInstalled(sdata
                                                                .setup![
                                                                    "widget_url2"]
                                                                .toString()
                                                                .split("details?id=")[
                                                                    1]
                                                                .split("&")[0])
                                                            : Future.value(
                                                                false),
                                                        onTap: () async {
                                                          if (sdata.setup![
                                                                  "widget_url2"]
                                                              .toString()
                                                              .contains(
                                                                  'play.google.com/store/apps/details?id=')) {
                                                            final isInstalled =
                                                                await DeviceApps.isAppInstalled(sdata
                                                                    .setup![
                                                                        "widget_url2"]
                                                                    .toString()
                                                                    .split("details?id=")[
                                                                        1]
                                                                    .split(
                                                                        "&")[0]);
                                                            isInstalled
                                                                ? DeviceApps.openApp(sdata
                                                                    .setup![
                                                                        "widget_url2"]
                                                                    .toString()
                                                                    .split("details?id=")[
                                                                        1]
                                                                    .split(
                                                                        "&")[0])
                                                                : launch(sdata
                                                                    .setup![
                                                                        "widget_url2"]
                                                                    .toString());
                                                          } else {
                                                            launch(sdata.setup![
                                                                    "widget_url2"]
                                                                .toString());
                                                          }
                                                        },
                                                        tileText: sdata
                                                            .setup!["widget2"]
                                                            .toString(),
                                                        tileType: "Widget",
                                                        panelCollapsed:
                                                            panelCollapsed,
                                                        delay: const Duration(
                                                            milliseconds: 300),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                    ),
                                  )
                                else
                                  Container(),
                                if (globals.prismUser.premium == true)
                                  Expanded(
                                    flex: 5,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: <Widget>[
                                        ModifiedShareDownloadButton(),
                                        ModifiedShareSetWallpaperButton(),
                                        Container(
                                          decoration: BoxDecoration(
                                            color:
                                                Theme.of(context).primaryColor,
                                            boxShadow: [
                                              BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(.25),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 4))
                                            ],
                                            borderRadius:
                                                BorderRadius.circular(500),
                                          ),
                                          padding: const EdgeInsets.all(17),
                                          child: FavoriteIcon(
                                            valueChanged: () {
                                              if (globals.prismUser.loggedIn ==
                                                  false) {
                                                googleSignInPopUp(context, () {
                                                  onFavSetup(
                                                      sdata.setup!["id"]
                                                          .toString(),
                                                      sdata.setup);
                                                });
                                              } else {
                                                onFavSetup(
                                                    sdata.setup!["id"]
                                                        .toString(),
                                                    sdata.setup);
                                              }
                                            },
                                            iconColor:
                                                Theme.of(context).accentColor,
                                            iconSize: 30,
                                            isFavorite: box.get(
                                                sdata.setup!["id"].toString(),
                                                defaultValue: false) as bool,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Expanded(
                                    flex: 5,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        GestureDetector(
                                          onTap: () async {
                                            if (globals.prismUser.loggedIn ==
                                                true) {
                                              Navigator.pushNamed(
                                                  context, premiumRoute);
                                            } else {
                                              googleSignInPopUp(context, () {
                                                Navigator.pushNamed(
                                                    context, premiumRoute);
                                              });
                                            }
                                            toasts.codeSend(
                                                "This is a premium wallpaper.");
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
                                                    offset: const Offset(0, 4))
                                              ],
                                              borderRadius:
                                                  BorderRadius.circular(500),
                                            ),
                                            padding: const EdgeInsets.all(17),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
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
                                                      .headline4,
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
                                logger.d('${offsetAnimation.value + 8.0}');
                              }
                              return GestureDetector(
                                onPanUpdate: (details) {
                                  if (details.delta.dy < -10) {
                                    panelController.open();
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
                                  imageUrl: sdata.setup!["image"].toString(),
                                  imageBuilder: (context, imageProvider) =>
                                      Container(
                                    margin: EdgeInsets.symmetric(
                                        vertical: offsetAnimation.value * 1.25,
                                        horizontal: offsetAnimation.value / 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                          offsetAnimation.value),
                                      image: DecorationImage(
                                        image: imageProvider,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  progressIndicatorBuilder:
                                      (context, url, downloadProgress) => Stack(
                                    children: <Widget>[
                                      const SizedBox.expand(
                                          child: Text(
                                        "",
                                        overflow: TextOverflow.fade,
                                      )),
                                      Center(
                                        child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation(
                                              Theme.of(context).errorColor,
                                            ),
                                            value: downloadProgress.progress),
                                      ),
                                    ],
                                  ),
                                  errorWidget: (context, url, error) => Center(
                                    child: Icon(
                                      JamIcons.close_circle_f,
                                      color: Theme.of(context).accentColor,
                                    ),
                                  ),
                                ),
                              );
                            }),
                        Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                8.0, globals.notchSize! + 8, 8, 8),
                            child: IconButton(
                              onPressed: () {
                                navStack.removeLast();
                                logger.d(navStack.toString());
                                Navigator.pop(context);
                              },
                              color: Theme.of(context).accentColor,
                              icon: const Icon(
                                JamIcons.chevron_left,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                8.0, globals.notchSize! + 8, 8, 8),
                            child: IconButton(
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                        transitionDuration:
                                            const Duration(milliseconds: 300),
                                        pageBuilder: (context, animation,
                                            secondaryAnimation) {
                                          animation =
                                              Tween(begin: 0.0, end: 1.0)
                                                  .animate(animation);
                                          return FadeTransition(
                                              opacity: animation,
                                              child: SetupOverlay(
                                                link: sdata.setup!["image"]
                                                    .toString(),
                                              ));
                                        },
                                        fullscreenDialog: true,
                                        opaque: false));
                              },
                              color: Theme.of(context).accentColor,
                              icon: const Icon(
                                JamIcons.arrow_up_right,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              default:
                return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}

class SetupDetailsTile extends StatelessWidget {
  final bool panelCollapsed;
  final Duration delay;
  final String tileType;
  final String tileText;
  final Function onTap;
  final Future<bool> isInstalled;
  const SetupDetailsTile({
    Key? key,
    required this.delay,
    required this.tileText,
    required this.tileType,
    required this.onTap,
    required this.panelCollapsed,
    required this.isInstalled,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return panelCollapsed
        ? Container()
        : ShowUpTransition(
            forward: true,
            delay: delay,
            slideSide: SlideFromSlide.bottom,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: 80,
                  child: Stack(
                    children: [
                      Positioned(
                        bottom: -55,
                        left: 0,
                        child: Text(
                          tileType,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            fontSize: 140,
                            color:
                                Theme.of(context).accentColor.withOpacity(0.1),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Theme.of(context).accentColor.withOpacity(0.1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                  flex: 10,
                                  child: Text(
                                    tileText,
                                    overflow: TextOverflow.fade,
                                    style: TextStyle(
                                      color: Theme.of(context).accentColor,
                                    ),
                                  )),
                              Expanded(
                                child: FutureBuilder<bool>(
                                  future: isInstalled,
                                  initialData: false,
                                  builder: (BuildContext context,
                                      AsyncSnapshot snapshot) {
                                    if (snapshot.data == true) {
                                      return Icon(
                                        JamIcons.check,
                                        color: Theme.of(context).accentColor,
                                      );
                                    }
                                    return Icon(
                                      JamIcons.chevron_right,
                                      color: Theme.of(context).accentColor,
                                    );
                                  },
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              splashColor: Theme.of(context)
                                  .accentColor
                                  .withOpacity(0.3),
                              highlightColor: Theme.of(context)
                                  .accentColor
                                  .withOpacity(0.1),
                              onTap: () {
                                onTap();
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
  }
}

class ModifiedShareDownloadButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return sdata.setup!["wallpaper_url"].toString()[0] != "["
        ? sdata.setup!["wall_id"] != null && sdata.setup!["wall_id"] != ""
            ? DownloadButton(
                link: sdata.setup!["wallpaper_url"].toString(),
              )
            : GestureDetector(
                onTap: () async {
                  launch(sdata.setup!["wallpaper_url"].toString());
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
              )
        : GestureDetector(
            onTap: () async {
              launch(sdata.setup!["wallpaper_url"][1].toString());
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
    return sdata.setup!["wallpaper_url"].toString()[0] != "["
        ? sdata.setup!["wall_id"] != null && sdata.setup!["wall_id"] != ""
            ? SetWallpaperButton(
                url: sdata.setup!["wallpaper_url"].toString(),
                colorChanged: false,
              )
            : GestureDetector(
                onTap: () async {
                  launch(sdata.setup!["wallpaper_url"].toString());
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
              )
        : GestureDetector(
            onTap: () async {
              launch(sdata.setup!["wallpaper_url"][1].toString());
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
