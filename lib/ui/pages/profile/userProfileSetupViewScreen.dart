import 'dart:ui';

import 'package:Prism/data/profile/wallpaper/getUserProfile.dart' as user_data;
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/home/core/collapsedPanel.dart';
import 'package:Prism/ui/widgets/menuButton/downloadButton.dart';
import 'package:Prism/ui/widgets/menuButton/setWallpaperButton.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/theme/config.dart' as config;
import 'package:Prism/main.dart' as main;
import 'package:Prism/global/globals.dart' as globals;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/data/favourites/provider/favouriteSetupProvider.dart';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/ui/widgets/animated/showUp.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';

class UserProfileSetupViewScreen extends StatefulWidget {
  final List arguments;
  const UserProfileSetupViewScreen({this.arguments});

  @override
  _UserProfileSetupViewScreenState createState() =>
      _UserProfileSetupViewScreenState();
}

class _UserProfileSetupViewScreenState extends State<UserProfileSetupViewScreen>
    with SingleTickerProviderStateMixin {
  Future<bool> onWillPop() async {
    navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int index;
  String thumb;
  bool isLoading = true;
  PanelController panelController = PanelController();
  AnimationController shakeController;
  bool panelCollapsed = true;

  @override
  void initState() {
    shakeController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    index = widget.arguments[0] as int;
    isLoading = true;
    super.initState();
  }

  @override
  void dispose() {
    shakeController.dispose();
    super.dispose();
  }

  Future<void> onFavSetup(String id, Map setupMap) async {
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
        resizeToAvoidBottomPadding: false,
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).primaryColor,
        body: SlidingUpPanel(
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
          maxHeight:
              // Provider.of<SetupProvider>(context, listen: false)
              //                 .setups[index]["widget2"] ==
              //             "" ||
              //         Provider.of<SetupProvider>(context, listen: false)
              //                 .setups[index]["widget2"] ==
              //             null
              // ?
              MediaQuery.of(context).size.height * .70 > 600
                  ? MediaQuery.of(context).size.height * .70
                  : 600
          // : MediaQuery.of(context).size.height * .85 > 650
          //     ? MediaQuery.of(context).size.height * .85
          //     : 650
          ,
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
            height:
                // Provider.of<SetupProvider>(context, listen: false)
                //                 .setups[index]["widget2"] ==
                //             "" ||
                //         Provider.of<SetupProvider>(context, listen: false)
                //                 .setups[index]["widget2"] ==
                //             null
                // ?
                MediaQuery.of(context).size.height * .70 > 600
                    ? MediaQuery.of(context).size.height * .70
                    : 600
            // : MediaQuery.of(context).size.height * .85 > 650
            //     ? MediaQuery.of(context).size.height * .85
            //     : 650
            ,
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
                        ? Theme.of(context).primaryColor.withOpacity(1)
                        : Theme.of(context).primaryColor.withOpacity(.5),
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
                            onTap: (){
                              panelController.close();
                            },
                                                      child: Icon(
                              JamIcons.chevron_down,
                              color: Theme.of(context).accentColor,
                            ),),
                        ),
                      )),
                      Expanded(
                        flex: 4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(35, 0, 35, 5),
                              child: panelCollapsed
                                  ? Container()
                                  : ShowUpTransition(
                                      forward: true,
                                      slideSide: SlideFromSlide.bottom,
                                      child: Text(
                                        user_data.userProfileSetups[index]
                                                ["name"]
                                            .toString()
                                            .toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.fade,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline1
                                            .copyWith(
                                                fontSize: 30,
                                                color: Theme.of(context)
                                                    .accentColor),
                                      ),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(35, 0, 35, 0),
                              child: panelCollapsed
                                  ? Container()
                                  : ShowUpTransition(
                                      forward: true,
                                      slideSide: SlideFromSlide.bottom,
                                      delay: const Duration(milliseconds: 50),
                                      child: Text(
                                        user_data.userProfileSetups[index]
                                                ["desc"]
                                            .toString(),
                                        maxLines: 2,
                                        overflow: TextOverflow.fade,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline6
                                            .copyWith(
                                                color: Theme.of(context)
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
                          padding: const EdgeInsets.fromLTRB(35, 0, 35, 10),
                          child: panelCollapsed
                              ? Container()
                              : ShowUpTransition(
                                  forward: true,
                                  delay: const Duration(milliseconds: 100),
                                  slideSide: SlideFromSlide.bottom,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: <Widget>[
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                0, 5, 0, 5),
                                            child: Text(
                                              user_data.userProfileSetups[index]
                                                      ["id"]
                                                  .toString()
                                                  .toUpperCase(),
                                              overflow: TextOverflow.fade,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyText1
                                                  .copyWith(
                                                      color: Theme.of(context)
                                                          .accentColor,
                                                      fontSize: 16),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () async {
                                              await createCopyrightLink(
                                                  true, context,
                                                  index: index.toString(),
                                                  name: user_data
                                                      .userProfileSetups[index]
                                                          ["name"]
                                                      .toString(),
                                                  thumbUrl: user_data
                                                      .userProfileSetups[index]
                                                          ["image"]
                                                      .toString());
                                            },
                                            child: Row(
                                              children: [
                                                Icon(
                                                  JamIcons.info,
                                                  size: 20,
                                                  color: Theme.of(context)
                                                      .accentColor
                                                      .withOpacity(.7),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  "Copyright",
                                                  overflow: TextOverflow.fade,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyText2
                                                      .copyWith(
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: <Widget>[
                                          SizedBox(
                                            width: 150,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Stack(
                                                children: [
                                                  Align(
                                                    alignment:
                                                        Alignment.topRight,
                                                    child: ActionChip(
                                                        label: Text(
                                                          user_data
                                                              .userProfileSetups[
                                                                  index]["by"]
                                                              .toString(),
                                                          overflow:
                                                              TextOverflow.fade,
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodyText2
                                                              .copyWith(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .accentColor),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                    .symmetric(
                                                                vertical: 5,
                                                                horizontal: 5),
                                                        avatar: CircleAvatar(
                                                          backgroundImage:
                                                              CachedNetworkImageProvider(user_data
                                                                  .userProfileSetups[
                                                                      index][
                                                                      "userPhoto"]
                                                                  .toString()),
                                                        ),
                                                        labelPadding:
                                                            const EdgeInsets
                                                                    .fromLTRB(
                                                                7, 3, 7, 3),
                                                        onPressed: () {
                                                          Navigator.pushNamed(
                                                              context,
                                                              photographerProfileRoute,
                                                              arguments: [
                                                                user_data.userProfileSetups[
                                                                        index]
                                                                    ["by"],
                                                                user_data.userProfileSetups[
                                                                        index]
                                                                    ["email"],
                                                                user_data.userProfileSetups[
                                                                        index][
                                                                    "userPhoto"],
                                                                false,
                                                                user_data.userProfileSetups[index]["twitter"] !=
                                                                            null &&
                                                                        user_data.userProfileSetups[index]["twitter"] !=
                                                                            ""
                                                                    ? user_data
                                                                        .userProfileSetups[
                                                                            index]
                                                                            [
                                                                            "twitter"]
                                                                        .toString()
                                                                        .split(
                                                                            "https://www.twitter.com/")[1]
                                                                    : "",
                                                                user_data.userProfileSetups[index]["instagram"] !=
                                                                            null &&
                                                                        user_data.userProfileSetups[index]["instagram"] !=
                                                                            ""
                                                                    ? user_data
                                                                        .userProfileSetups[
                                                                            index]
                                                                            [
                                                                            "instagram"]
                                                                        .toString()
                                                                        .split(
                                                                            "https://www.instagram.com/")[1]
                                                                    : "",
                                                              ]);
                                                        }),
                                                  ),
                                                  globals.verifiedUsers
                                                          .contains(user_data
                                                              .userProfileSetups[
                                                                  index]
                                                                  ["email"]
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
                                                                    : main.prefs
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
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      Expanded(
                        flex: 16,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(35, 0, 35, 0),
                          child: user_data.userProfileSetups[index]["widget"] ==
                                      "" ||
                                  user_data.userProfileSetups[index]
                                          ["widget"] ==
                                      null
                              ? Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SetupDetailsTile(
                                      onTap: () async {
                                        if (user_data.userProfileSetups[index]
                                                    ["wallpaper_url"]
                                                .toString()[0] !=
                                            "[") {
                                          if (user_data.userProfileSetups[index]
                                                  ["wall_id"] ==
                                              null) {
                                            debugPrint("Id Not Found!");
                                             launch(user_data
                                              .userProfileSetups[index]
                                                  ["wallpaper_url"]
                                              .toString());
                                          } else {
                                            Navigator.pushNamed(
                                                context, shareRoute,
                                                arguments: [
                                                  user_data
                                                      .userProfileSetups[index]
                                                          ["wall_id"]
                                                      .toString(),
                                                  user_data
                                                      .userProfileSetups[index]
                                                          ["wallpaper_provider"]
                                                      .toString(),
                                                  user_data
                                                      .userProfileSetups[index]
                                                          ["wallpaper_url"]
                                                      .toString(),
                                                  user_data
                                                      .userProfileSetups[index]
                                                          ["wallpaper_url"]
                                                      .toString(),
                                                ]);
                                          }
                                        } else {
                                          launch(user_data
                                              .userProfileSetups[index]
                                                  ["wallpaper_url"][1]
                                              .toString());
                                        }
                                      },
                                      tileText: user_data
                                                  .userProfileSetups[index]
                                                      ["wallpaper_url"]
                                                  .toString()[0] !=
                                              "["
                                          ? "Prism"
                                          : user_data.userProfileSetups[index]
                                                      ["wallpaper_url"][0]
                                                  .toString() +
                                              " - " +
                                              ((user_data.userProfileSetups[index]
                                                                  ["wallpaper_url"]
                                                              as List)
                                                          .length >
                                                      2
                                                  ? user_data
                                                      .userProfileSetups[index]
                                                          ["wallpaper_url"][2]
                                                      .toString()
                                                  : ""),
                                      tileType: "Wallpaper",
                                      panelCollapsed: panelCollapsed,
                                      delay: const Duration(milliseconds: 150),
                                    ),
                                    SetupDetailsTile(
                                      onTap: () async {
                                        launch(user_data
                                            .userProfileSetups[index]
                                                ["icon_url"]
                                            .toString());
                                      },
                                      tileText: user_data
                                          .userProfileSetups[index]["icon"]
                                          .toString(),
                                      tileType: "Icons",
                                      panelCollapsed: panelCollapsed,
                                      delay: const Duration(milliseconds: 200),
                                    ),
                                  ],
                                )
                              : user_data.userProfileSetups[index]["widget2"] ==
                                          "" ||
                                      user_data.userProfileSetups[index]
                                              ["widget2"] ==
                                          null
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SetupDetailsTile(
                                          onTap: () async {
                                            if (user_data
                                                    .userProfileSetups[index]
                                                        ["wallpaper_url"]
                                                    .toString()[0] !=
                                                "[") {
                                              if (user_data.userProfileSetups[
                                                      index]["wall_id"] ==
                                                  null) {
                                                debugPrint("Id Not Found!");
                                                 launch(user_data
                                                  .userProfileSetups[index]
                                                      ["wallpaper_url"]
                                                  .toString());
                                              } else {
                                                Navigator.pushNamed(
                                                    context, shareRoute,
                                                    arguments: [
                                                      user_data
                                                          .userProfileSetups[
                                                              index]["wall_id"]
                                                          .toString(),
                                                      user_data
                                                          .userProfileSetups[
                                                              index][
                                                              "wallpaper_provider"]
                                                          .toString(),
                                                      user_data
                                                          .userProfileSetups[
                                                              index]
                                                              ["wallpaper_url"]
                                                          .toString(),
                                                      user_data
                                                          .userProfileSetups[
                                                              index]
                                                              ["wallpaper_url"]
                                                          .toString(),
                                                    ]);
                                              }
                                            } else {
                                              launch(user_data
                                                  .userProfileSetups[index]
                                                      ["wallpaper_url"][1]
                                                  .toString());
                                            }
                                          },
                                          tileText: user_data.userProfileSetups[index]
                                                          ["wallpaper_url"]
                                                      .toString()[0] !=
                                                  "["
                                              ? "Prism"
                                              : user_data.userProfileSetups[index]
                                                          ["wallpaper_url"][0]
                                                      .toString() +
                                                  " - " +
                                                  ((user_data.userProfileSetups[index]
                                                                      ["wallpaper_url"]
                                                                  as List)
                                                              .length >
                                                          2
                                                      ? user_data
                                                          .userProfileSetups[index]
                                                              ["wallpaper_url"][2]
                                                          .toString()
                                                      : ""),
                                          tileType: "Wallpaper",
                                          panelCollapsed: panelCollapsed,
                                          delay:
                                              const Duration(milliseconds: 150),
                                        ),
                                        SetupDetailsTile(
                                          onTap: () async {
                                            launch(user_data
                                                .userProfileSetups[index]
                                                    ["icon_url"]
                                                .toString());
                                          },
                                          tileText: user_data
                                              .userProfileSetups[index]["icon"]
                                              .toString(),
                                          tileType: "Icons",
                                          panelCollapsed: panelCollapsed,
                                          delay:
                                              const Duration(milliseconds: 200),
                                        ),
                                        SetupDetailsTile(
                                          onTap: () async {
                                            launch(user_data
                                                .userProfileSetups[index]
                                                    ["widget_url"]
                                                .toString());
                                          },
                                          tileText: user_data
                                              .userProfileSetups[index]
                                                  ["widget"]
                                              .toString(),
                                          tileType: "Widget",
                                          panelCollapsed: panelCollapsed,
                                          delay:
                                              const Duration(milliseconds: 250),
                                        ),
                                      ],
                                    )
                                  : Scrollbar(
                                      radius: const Radius.circular(500),
                                      thickness: 5,
                                      child: ListView(
                                        children: [
                                          SetupDetailsTile(
                                            onTap: () async {
                                              if (user_data
                                                      .userProfileSetups[index]
                                                          ["wallpaper_url"]
                                                      .toString()[0] !=
                                                  "[") {
                                                if (user_data.userProfileSetups[
                                                        index]["wall_id"] ==
                                                    null) {
                                                  debugPrint("Id Not Found!");
                                                   launch(user_data
                                                    .userProfileSetups[index]
                                                        ["wallpaper_url"]
                                                    .toString());
                                                } else {
                                                  Navigator.pushNamed(
                                                      context, shareRoute,
                                                      arguments: [
                                                        user_data
                                                            .userProfileSetups[
                                                                index]
                                                                ["wall_id"]
                                                            .toString(),
                                                        user_data
                                                            .userProfileSetups[
                                                                index][
                                                                "wallpaper_provider"]
                                                            .toString(),
                                                        user_data
                                                            .userProfileSetups[
                                                                index][
                                                                "wallpaper_url"]
                                                            .toString(),
                                                        user_data
                                                            .userProfileSetups[
                                                                index][
                                                                "wallpaper_url"]
                                                            .toString(),
                                                      ]);
                                                }
                                              } else {
                                                launch(user_data
                                                    .userProfileSetups[index]
                                                        ["wallpaper_url"][1]
                                                    .toString());
                                              }
                                            },
                                            tileText: user_data.userProfileSetups[index]
                                                            ["wallpaper_url"]
                                                        .toString()[0] !=
                                                    "["
                                                ? "Prism"
                                                : user_data.userProfileSetups[index]
                                                            ["wallpaper_url"][0]
                                                        .toString() +
                                                    " - " +
                                                    ((user_data.userProfileSetups[index]
                                                                        ["wallpaper_url"]
                                                                    as List)
                                                                .length >
                                                            2
                                                        ? user_data
                                                            .userProfileSetups[index]
                                                                ["wallpaper_url"][2]
                                                            .toString()
                                                        : ""),
                                            tileType: "Wallpaper",
                                            panelCollapsed: panelCollapsed,
                                            delay: const Duration(
                                                milliseconds: 150),
                                          ),
                                          SetupDetailsTile(
                                            onTap: () async {
                                              launch(user_data
                                                  .userProfileSetups[index]
                                                      ["icon_url"]
                                                  .toString());
                                            },
                                            tileText: user_data
                                                .userProfileSetups[index]
                                                    ["icon"]
                                                .toString(),
                                            tileType: "Icons",
                                            panelCollapsed: panelCollapsed,
                                            delay: const Duration(
                                                milliseconds: 200),
                                          ),
                                          SetupDetailsTile(
                                            onTap: () async {
                                              launch(user_data
                                                  .userProfileSetups[index]
                                                      ["widget_url"]
                                                  .toString());
                                            },
                                            tileText: user_data
                                                .userProfileSetups[index]
                                                    ["widget"]
                                                .toString(),
                                            tileType: "Widget",
                                            panelCollapsed: panelCollapsed,
                                            delay: const Duration(
                                                milliseconds: 250),
                                          ),
                                          SetupDetailsTile(
                                            onTap: () async {
                                              launch(user_data
                                                  .userProfileSetups[index]
                                                      ["widget_url2"]
                                                  .toString());
                                            },
                                            tileText: user_data
                                                .userProfileSetups[index]
                                                    ["widget2"]
                                                .toString(),
                                            tileType: "Widget",
                                            panelCollapsed: panelCollapsed,
                                            delay: const Duration(
                                                milliseconds: 300),
                                          ),
                                        ],
                                      ),
                                    ),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            ModifiedDownloadButton(index: index),
                            ModifiedSetWallpaperButton(index: index),
                            GestureDetector(
                              onTap: () {
                                if (main.prefs.get("isLoggedin") == false) {
                                  googleSignInPopUp(context, () {
                                    onFavSetup(
                                        user_data.userProfileSetups[index]["id"]
                                            .toString(),
                                        user_data.userProfileSetups[index]
                                            as Map);
                                  });
                                } else {
                                  onFavSetup(
                                      user_data.userProfileSetups[index]["id"]
                                          .toString(),
                                      user_data.userProfileSetups[index]
                                          as Map);
                                }
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
                                  JamIcons.heart,
                                  color: Theme.of(context).accentColor,
                                  size: 20,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                createSetupDynamicLink(
                                    index.toString(),
                                    user_data.userProfileSetups[index]["name"]
                                        .toString(),
                                    user_data.userProfileSetups[index]["image"]
                                        .toString());
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
                                  JamIcons.share_alt,
                                  color: Theme.of(context).accentColor,
                                  size: 20,
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
                        imageUrl: user_data.userProfileSetups[index]["image"]
                            .toString(),
                        imageBuilder: (context, imageProvider) => Container(
                          margin: EdgeInsets.symmetric(
                              vertical: offsetAnimation.value * 1.25,
                              horizontal: offsetAnimation.value / 2),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(offsetAnimation.value),
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
                                    config.Colors().mainAccentColor(1),
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
                  padding:
                      EdgeInsets.fromLTRB(8.0, globals.notchSize + 8, 8, 8),
                  child: IconButton(
                    onPressed: () {
                      navStack.removeLast();
                      debugPrint(navStack.toString());
                      Navigator.pop(context);
                    },
                    color: Theme.of(context).accentColor,
                    icon: const Icon(
                      JamIcons.chevron_left,
                    ),
                  ),
                ),
              ),

              // Align(
              //   alignment: Alignment.topRight,
              //   child: Padding(
              //     padding: const EdgeInsets.all(8.0),
              //     child: IconButton(
              //       onPressed: () {
              //         createSetupDynamicLink(
              //             index.toString(),
              //             Provider.of<SetupProvider>(context, listen: false)
              //                 .profileSetups[index]["name"]
              //                 .toString(),
              //             Provider.of<SetupProvider>(context, listen: false)
              //                 .profileSetups[index]["image"]
              //                 .toString());
              //       },
              //       color: isLoading
              //           ? Theme.of(context).accentColor
              //           : colors[0].computeLuminance() > 0.5
              //               ? Colors.black
              //               : Colors.white,
              //       icon: const Icon(
              //         JamIcons.share_alt,
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
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
  const SetupDetailsTile({
    Key key,
    @required this.delay,
    @required this.tileText,
    @required this.tileType,
    @required this.onTap,
    @required this.panelCollapsed,
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
                                child: Icon(
                                  JamIcons.chevron_right,
                                  color: Theme.of(context).accentColor,
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

class ModifiedDownloadButton extends StatelessWidget {
  final int index;
  const ModifiedDownloadButton({@required this.index});
  @override
  Widget build(BuildContext context) {
    return user_data.userProfileSetups[index]["wallpaper_url"].toString()[0] !=
            "["
        ? DownloadButton(
            link:
                user_data.userProfileSetups[index]["wallpaper_url"].toString(),
            colorChanged: false,
          )
        : GestureDetector(
            onTap: () async {
              launch(user_data.userProfileSetups[index]["wallpaper_url"][1]
                  .toString());
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

class ModifiedSetWallpaperButton extends StatelessWidget {
  final int index;
  const ModifiedSetWallpaperButton({@required this.index});
  @override
  Widget build(BuildContext context) {
    return user_data.userProfileSetups[index]["wallpaper_url"].toString()[0] !=
            "["
        ? SetWallpaperButton(
            url: user_data.userProfileSetups[index]["wallpaper_url"].toString(),
            colorChanged: false,
          )
        : GestureDetector(
            onTap: () async {
              launch(user_data.userProfileSetups[index]["wallpaper_url"][1]
                  .toString());
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
