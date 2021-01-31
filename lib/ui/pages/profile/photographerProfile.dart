import 'dart:async';
import 'dart:convert';
import 'package:Prism/gitkey.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/profile/userProfileLoader.dart';
import 'package:Prism/ui/widgets/profile/userProfileSetupLoader.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:Prism/data/profile/wallpaper/getUserProfile.dart' as userData;
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

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
  final Firestore firestore = Firestore.instance;
  final key = GlobalKey();
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
    if (main.prefs.get('followTooltipShow', defaultValue: false) as bool) {
    } else {
      Future.delayed(const Duration(milliseconds: 500)).then((_) {
        try {
          final dynamic tooltip = key.currentState;
          tooltip.ensureTooltipVisible();
          main.prefs.put('followTooltipShow', true);
          Future.delayed(const Duration(seconds: 5)).then((_) {
            tooltip.deactivate();
          });
        } catch (e) {
          debugPrint(e.toString());
        }
      });
    }
    CollectionReference users = firestore.collection('users');
    return WillPopScope(
        onWillPop: onWillPop,
        child: DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: Theme.of(context).primaryColor,
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
                SliverAppBar(
                  backgroundColor: Theme.of(context).errorColor,
                  automaticallyImplyLeading: false,
                  expandedHeight: 200.0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          color: Theme.of(context).errorColor,
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
                                          TableCellVerticalAlignment.middle,
                                      child: Column(
                                        children: [
                                          name == null
                                              ? Container()
                                              : premium == false
                                                  ? Text(
                                                      name
                                                          .toString()
                                                          .toUpperCase(),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                          fontFamily:
                                                              "Proxima Nova",
                                                          color:
                                                              Theme.of(context)
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
                                                                    color: Theme.of(
                                                                            context)
                                                                        .errorColor,
                                                                  ),
                                                            ),
                                                          ),
                                                        )
                                                      ],
                                                    ),
                                          const Text("Write bio here...")
                                        ],
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
                                                          fontSize: 22,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                          fontWeight: FontWeight
                                                              .normal),
                                                    );
                                                  }),
                                              Icon(
                                                JamIcons.picture,
                                                size: 20,
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
                                                          fontSize: 22,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                          fontWeight: FontWeight
                                                              .normal),
                                                    );
                                                  }),
                                              Icon(
                                                JamIcons.instant_picture,
                                                size: 20,
                                                color: Theme.of(context)
                                                    .accentColor,
                                              ),
                                            ],
                                          ),
                                          StreamBuilder<QuerySnapshot>(
                                              stream: users
                                                  .where("email",
                                                      isEqualTo: email)
                                                  .snapshots(),
                                              builder: (BuildContext context,
                                                  AsyncSnapshot<QuerySnapshot>
                                                      snapshot) {
                                                if (!snapshot.hasData) {
                                                  return Row(
                                                    children: [
                                                      const SizedBox(width: 15),
                                                      Text(
                                                        "0",
                                                        style: TextStyle(
                                                            fontFamily:
                                                                "Proxima Nova",
                                                            fontSize: 22,
                                                            color: Theme.of(
                                                                    context)
                                                                .accentColor,
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal),
                                                      ),
                                                      Icon(
                                                        JamIcons.users,
                                                        size: 20,
                                                        color: Theme.of(context)
                                                            .accentColor,
                                                      ),
                                                    ],
                                                  );
                                                } else if (snapshot
                                                            .data.documents !=
                                                        null &&
                                                    snapshot.data.documents
                                                        .isNotEmpty) {
                                                  List followers = [];

                                                  followers = snapshot
                                                              .data
                                                              .documents[0]
                                                              .data['followers']
                                                          as List ??
                                                      [];

                                                  return Row(
                                                    children: [
                                                      const SizedBox(width: 15),
                                                      Text(
                                                        followers.length
                                                            .toString(),
                                                        style: TextStyle(
                                                            fontFamily:
                                                                "Proxima Nova",
                                                            fontSize: 22,
                                                            color: Theme.of(
                                                                    context)
                                                                .accentColor,
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal),
                                                      ),
                                                      Icon(
                                                        JamIcons.users,
                                                        size: 20,
                                                        color: Theme.of(context)
                                                            .accentColor,
                                                      ),
                                                    ],
                                                  );
                                                } else {
                                                  return Container();
                                                }
                                              }),
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
                  actions: [
                    main.prefs.get("isLoggedin") as bool == true &&
                            main.prefs.get('email') as String != email
                        ? StreamBuilder<QuerySnapshot>(
                            stream: users
                                .where("email",
                                    isEqualTo: main.prefs.get('email'))
                                .snapshots(),
                            builder: (BuildContext context,
                                AsyncSnapshot<QuerySnapshot> snapshot) {
                              if (!snapshot.hasData) {
                                return Container();
                              } else {
                                final List following = snapshot
                                        .data
                                        .documents[0]
                                        .data['following'] as List ??
                                    [];
                                if (following.contains(email)) {
                                  return IconButton(
                                    icon: const Icon(JamIcons.user_remove),
                                    onPressed: () {
                                      following
                                          .removeAt(following.indexOf(email));
                                      snapshot.data.documents[0].reference
                                          .updateData({'following': following});
                                      users
                                          .where("email", isEqualTo: email)
                                          .getDocuments()
                                          .then((value) {
                                        if (value.documents.isEmpty ||
                                            value.documents == null) {
                                        } else {
                                          final List followers = value
                                                  .documents[0]
                                                  .data['followers'] as List ??
                                              [];
                                          followers.removeAt(followers.indexOf(
                                              main.prefs.get('email')));
                                          value.documents[0].reference
                                              .updateData(
                                                  {'followers': followers});
                                        }
                                      });
                                      toasts.error("Unfollowed $name!");
                                    },
                                  );
                                } else {
                                  return Tooltip(
                                    margin: EdgeInsets.fromLTRB(
                                        MediaQuery.of(context).size.width * 0.4,
                                        0,
                                        16,
                                        0),
                                    showDuration: const Duration(seconds: 4),
                                    key: key,
                                    padding:
                                        const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                    message:
                                        "Follow $name to get notified for new posts!",
                                    child: IconButton(
                                      icon: const Icon(JamIcons.user_plus),
                                      onPressed: () {
                                        following.add(email);
                                        snapshot.data.documents[0].reference
                                            .updateData(
                                                {'following': following});
                                        users
                                            .where("email", isEqualTo: email)
                                            .getDocuments()
                                            .then((value) {
                                          if (value.documents.isEmpty ||
                                              value.documents == null) {
                                          } else {
                                            final List followers = value
                                                        .documents[0]
                                                        .data['followers']
                                                    as List ??
                                                [];
                                            followers
                                                .add(main.prefs.get('email'));
                                            value.documents[0].reference
                                                .updateData(
                                                    {'followers': followers});
                                          }
                                        });
                                        http.post(
                                          'https://fcm.googleapis.com/fcm/send',
                                          headers: <String, String>{
                                            'Content-Type': 'application/json',
                                            'Authorization':
                                                'key=$fcmServerToken',
                                          },
                                          body: jsonEncode(
                                            <String, dynamic>{
                                              'notification': <String, dynamic>{
                                                'title': '🎉 New Follower!',
                                                'body':
                                                    '${main.prefs.get('googlename')} is now following you.',
                                                'color': "#e57697",
                                                'tag':
                                                    '${main.prefs.get('googlename')} Follow',
                                                'image':
                                                    "${main.prefs.get('googleimage')}",
                                                'android_channel_id':
                                                    "followers",
                                                'tag':
                                                    '${main.prefs.get('googlename')} Follow',
                                              },
                                              'priority': 'high',
                                              'data': <String, dynamic>{
                                                'click_action':
                                                    'FLUTTER_NOTIFICATION_CLICK',
                                                'id': '1',
                                                'status': 'done'
                                              },
                                              'to':
                                                  "/topics/${email.split("@")[0]}"
                                            },
                                          ),
                                        );
                                        toasts.codeSend("Followed $name!");
                                      },
                                    ),
                                  );
                                }
                              }
                            },
                          )
                        : Container(),
                  ],
                ),
                SliverAppBar(
                  backgroundColor: Theme.of(context).errorColor,
                  automaticallyImplyLeading: false,
                  pinned: true,
                  titleSpacing: 0,
                  expandedHeight: 50,
                  title: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: 57,
                    child: Container(
                      color: Theme.of(context).errorColor,
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
