import 'dart:async';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/profile/userProfileLoader.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:Prism/data/profile/wallpaper/getUserProfile.dart' as userData;
import 'package:Prism/theme/config.dart' as config;
import 'package:Prism/main.dart' as main;
import 'package:flutter/services.dart';
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
          (navStack.last == "SharedWallpaper")) {
        SystemChrome.setEnabledSystemUIOverlays([]);
      }
    }
    debugPrint(navStack.toString());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: onWillPop,
        child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
              SliverAppBar(
                actions: [
                  twitter != "" && twitter != null
                      ? IconButton(
                          icon: const Icon(JamIcons.twitter),
                          onPressed: () {
                            launch("https://www.twitter.com/$twitter");
                          })
                      : Container(),
                  instagram != "" && instagram != null
                      ? IconButton(
                          icon: const Icon(JamIcons.instagram),
                          onPressed: () {
                            launch("https://www.instagram.com/$instagram");
                          })
                      : Container(),
                ],
                backgroundColor: config.Colors().mainAccentColor(1),
                pinned: true,
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
                          (navStack.last == "SharedWallpaper")) {
                        SystemChrome.setEnabledSystemUIOverlays([]);
                      }
                    }
                    debugPrint(navStack.toString());
                  },
                ),
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
                            userPhoto == null
                                ? Container()
                                : Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(5000),
                                            boxShadow: [
                                              BoxShadow(
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 4),
                                                  color: const Color(0xFF000000)
                                                      .withOpacity(0.24))
                                            ]),
                                        child: CircleAvatar(
                                          radius: 50,
                                          backgroundImage:
                                              NetworkImage(userPhoto),
                                        ),
                                      ),
                                      globals.verifiedUsers.contains(email)
                                          ? Positioned(
                                              top: 0,
                                              left: 70,
                                              child: Container(
                                                width: 30,
                                                height: 30,
                                                child: SvgPicture.string(
                                                    verifiedIcon.replaceAll(
                                                        "E57697", "FFFFFF")),
                                              ),
                                            )
                                          : Container(),
                                    ],
                                  ),
                            const Spacer(flex: 2),
                            premium == false
                                ? name == null
                                    ? Container()
                                    : Text(
                                        name,
                                        style: const TextStyle(
                                            fontFamily: "Proxima Nova",
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.w700),
                                      )
                                : name == null
                                    ? Container()
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            name,
                                            style: const TextStyle(
                                                fontFamily: "Proxima Nova",
                                                color: Colors.white,
                                                fontSize: 32,
                                                fontWeight: FontWeight.w700),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 8.0),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 3,
                                                      horizontal: 5),
                                              decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(50),
                                                  color:
                                                      const Color(0xFFFFFFFF)),
                                              child: Text(
                                                "PRO",
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyText2
                                                    .copyWith(
                                                        fontSize: 10,
                                                        color: Color(main.prefs.get(
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
                                    FutureBuilder(
                                        future: userData
                                            .getProfileWallsLength(email),
                                        builder: (context, snapshot) {
                                          return Text(
                                            snapshot.data == null
                                                ? "0 "
                                                : "${snapshot.data.toString()} ",
                                            style: const TextStyle(
                                                fontFamily: "Proxima Nova",
                                                fontSize: 24,
                                                color: Colors.white70,
                                                fontWeight: FontWeight.normal),
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
                            const Spacer(flex: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            body: Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: UserProfileLoader(
                email: email,
                future: userData.getuserProfileWalls(email),
              ),
            ),
          ),
        ));
  }
}
