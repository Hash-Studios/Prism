import 'dart:async';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/profile/userProfileLoader.dart';
import 'package:Prism/ui/widgets/profile/userProfileSetupLoader.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:Prism/data/profile/wallpaper/getUserProfile.dart' as userData;
import 'package:Prism/theme/config.dart' as config;
import 'package:Prism/main.dart' as main;
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:Prism/global/svgAssets.dart';

class UserProfile extends StatefulWidget {
  final List arguments;
  const UserProfile(this.arguments);
  @override
  _UserProfileState createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  String name;
  String email;
  String userPhoto;
  bool premium;
  String twitter;
  String instagram;
  final ScrollController scrollController = ScrollController();
  @override
  void initState() {
    name = widget.arguments[0].toString();
    email = widget.arguments[1].toString();
    userPhoto = widget.arguments[2].toString();
    premium = widget.arguments[3] as bool;
    twitter = widget.arguments[4].toString();
    instagram = widget.arguments[5].toString();
    super.initState();
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) {
      navStack.removeLast();
      if ((navStack.last == "Wallpaper") ||
          (navStack.last == "Search Wallpaper") ||
          (navStack.last == "SharedWallpaper") ||
          (navStack.last == "SetupView")) {}
    }
    debugPrint(navStack.toString());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: onWillPop,
        child: DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: Theme.of(context).primaryColor,
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
                SliverAppBar(
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
                          padding: const EdgeInsets.fromLTRB(16, 25, 16, 0),
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
                                      child: userPhoto == null
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
                                                            offset:
                                                                const Offset(
                                                                    0, 4),
                                                            color: const Color(
                                                                    0xFF000000)
                                                                .withOpacity(
                                                                    0.24))
                                                      ]),
                                                  child: CircleAvatar(
                                                    radius: 50,
                                                    backgroundImage:
                                                        NetworkImage(userPhoto
                                                            .toString()),
                                                  ),
                                                ),
                                                globals.verifiedUsers.contains(
                                                        email.toString())
                                                    ? Positioned(
                                                        top: 5,
                                                        left: 100,
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
                                    ),
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.bottom,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 20),
                                        child: name == null
                                            ? Container()
                                            : premium == false
                                                ? Text(
                                                    name
                                                        .toString()
                                                        .toUpperCase(),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                        fontFamily:
                                                            "Proxima Nova",
                                                        color: Theme.of(context)
                                                            .accentColor,
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  )
                                                : Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: <Widget>[
                                                      Text(
                                                        name
                                                            .toString()
                                                            .toUpperCase(),
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
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                    .only(
                                                                left: 6.0),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                      .symmetric(
                                                                  vertical: 2,
                                                                  horizontal:
                                                                      4),
                                                          decoration:
                                                              BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
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
                                                                  fontSize: 9,
                                                                  color: Color(main
                                                                          .prefs
                                                                          .get(
                                                                              "mainAccentColor")
                                                                      as int),
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
                                          TableCellVerticalAlignment.middle,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          twitter != "" && twitter != null
                                              ? IconButton(
                                                  icon: Icon(
                                                    JamIcons.twitter,
                                                    color: Theme.of(context)
                                                        .accentColor,
                                                  ),
                                                  onPressed: () {
                                                    launch(
                                                        "https://www.twitter.com/$twitter");
                                                  })
                                              : Container(),
                                          instagram != "" && instagram != null
                                              ? IconButton(
                                                  icon: Icon(
                                                    JamIcons.instagram,
                                                    color: Theme.of(context)
                                                        .accentColor,
                                                  ),
                                                  onPressed: () {
                                                    launch(
                                                        "https://www.instagram.com/$instagram");
                                                  })
                                              : Container(),
                                        ],
                                      ),
                                    ),
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          const Spacer(flex: 2),
                                          Row(
                                            children: <Widget>[
                                              FutureBuilder(
                                                  future: userData
                                                      .getProfileWallsLength(
                                                          email),
                                                  builder: (context, snapshot) {
                                                    return Text(
                                                      snapshot.data == null
                                                          ? "0 "
                                                          : "${snapshot.data.toString()} ",
                                                      style: TextStyle(
                                                          fontFamily:
                                                              "Proxima Nova",
                                                          fontSize: 24,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                          fontWeight: FontWeight
                                                              .normal),
                                                    );
                                                  }),
                                              Icon(
                                                JamIcons.picture,
                                                color: Theme.of(context)
                                                    .accentColor,
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          Row(
                                            children: <Widget>[
                                              FutureBuilder(
                                                  future: userData
                                                      .getProfileSetupsLength(
                                                          email),
                                                  builder: (context, snapshot) {
                                                    return Text(
                                                      snapshot.data == null
                                                          ? "0 "
                                                          : "${snapshot.data.toString()} ",
                                                      style: TextStyle(
                                                          fontFamily:
                                                              "Proxima Nova",
                                                          fontSize: 24,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                          fontWeight: FontWeight
                                                              .normal),
                                                    );
                                                  }),
                                              Icon(
                                                JamIcons.instant_picture,
                                                color: Theme.of(context)
                                                    .accentColor,
                                              ),
                                            ],
                                          ),
                                          const Spacer(flex: 2),
                                        ],
                                      ),
                                    ),
                                  ]),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  leading: IconButton(
                    icon: const Icon(
                      JamIcons.chevron_left,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      if (navStack.length > 1) {
                        navStack.removeLast();
                        if ((navStack.last == "Wallpaper") ||
                            (navStack.last == "Search Wallpaper") ||
                            (navStack.last == "SharedWallpaper") ||
                            (navStack.last == "SetupView")) {}
                      }
                      debugPrint(navStack.toString());
                    },
                  ),
                ),
                SliverAppBar(
                  backgroundColor: config.Colors().mainAccentColor(1),
                  automaticallyImplyLeading: false,
                  pinned: true,
                  titleSpacing: 0,
                  expandedHeight: 50,
                  title: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: 57,
                    child: Container(
                      color: config.Colors().mainAccentColor(1),
                      child: SizedBox.expand(
                        child: TabBar(
                            indicatorColor: Theme.of(context).accentColor,
                            indicatorSize: TabBarIndicatorSize.label,
                            unselectedLabelColor:
                                const Color(0xFFFFFFFF).withOpacity(0.5),
                            labelColor: const Color(0xFFFFFFFF),
                            tabs: [
                              Text(
                                "Wallpapers",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText2
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                              ),
                              Text(
                                "Setups",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText2
                                    .copyWith(
                                        color: Theme.of(context).accentColor),
                              ),
                            ]),
                      ),
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5.0),
                    child: UserProfileLoader(
                      email: email,
                      future: userData.getuserProfileWalls(email),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 5.0),
                    child: UserProfileSetupLoader(
                      email: email,
                      future: userData.getUserProfileSetups(email),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
