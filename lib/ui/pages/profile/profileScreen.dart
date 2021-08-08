import 'dart:async';
import 'dart:convert';
import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/data/favourites/provider/favouriteSetupProvider.dart';
import 'package:Prism/data/profile/wallpaper/getUserProfile.dart';
import 'package:Prism/data/profile/wallpaper/profileSetupProvider.dart';
import 'package:Prism/data/profile/wallpaper/profileWallProvider.dart';
import 'package:Prism/gitkey.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/popup/editProfilePanel.dart';
import 'package:Prism/ui/widgets/popup/linkPopUp.dart';
import 'package:Prism/ui/widgets/popup/noLoadLinkPopUp.dart';
import 'package:Prism/ui/widgets/profile/aboutList.dart';
import 'package:Prism/ui/widgets/profile/drawerWidget.dart';
import 'package:Prism/ui/widgets/profile/generalList.dart';
import 'package:Prism/ui/widgets/profile/downloadList.dart';
import 'package:Prism/ui/widgets/profile/premiumList.dart';
import 'package:Prism/ui/widgets/home/core/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/core/inheritedScrollControllerProvider.dart';
import 'package:Prism/ui/widgets/profile/uploadedWallsLoader.dart';
import 'package:Prism/ui/widgets/profile/uploadedSetupsLoader.dart';
import 'package:Prism/ui/widgets/profile/userList.dart';
import 'package:Prism/ui/widgets/profile/userProfileLoader.dart';
import 'package:Prism/ui/widgets/profile/userProfileSetupLoader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:provider/provider.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

class ProfileScreen extends StatefulWidget {
  final List? arguments;
  const ProfileScreen(this.arguments);
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? email;

  @override
  void initState() {
    email = widget.arguments![0].toString();
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
      child: (email == globals.prismUser.email)
          ? Scaffold(
              key: scaffoldKey,
              body: BottomBar(
                child: ProfileChild(
                  ownProfile: true,
                  id: globals.prismUser.id,
                  bio: globals.prismUser.bio,
                  coverPhoto: globals.prismUser.coverPhoto,
                  email: globals.prismUser.email,
                  links: globals.prismUser.links,
                  name: globals.prismUser.name,
                  premium: globals.prismUser.premium,
                  userPhoto: globals.prismUser.profilePhoto,
                  username: globals.prismUser.username,
                  followers: globals.prismUser.followers,
                  following: globals.prismUser.following,
                ),
              ),
              endDrawer: globals.prismUser.loggedIn
                  ? SizedBox(
                      width: MediaQuery.of(context).size.width * 0.68,
                      child: ProfileDrawer())
                  : null,
            )
          : Scaffold(
              key: scaffoldKey,
              body: StreamBuilder<QuerySnapshot>(
                stream: getUserProfile(email!),
                builder: (BuildContext context,
                    AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    if (snapshot.data!.docs.isEmpty) {
                      return Container(
                        color: Theme.of(context).primaryColor,
                        child: Center(
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.8,
                            child: const Text(
                              "Sorry! This user is inactive on the latest version, and hence they are not currently viewable.",
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }
                    return ProfileChild(
                      ownProfile: false,
                      id: snapshot.data!.docs[0].id,
                      bio: snapshot.data!.docs[0].data()["bio"].toString(),
                      coverPhoto:
                          snapshot.data!.docs[0].data()["coverPhoto"] as String,
                      email: snapshot.data!.docs[0].data()["email"].toString(),
                      links: snapshot.data!.docs[0].data()["links"] as Map,
                      name: snapshot.data!.docs[0].data()["name"].toString(),
                      premium: snapshot.data!.docs[0].data()["premium"] as bool,
                      userPhoto: snapshot.data!.docs[0]
                          .data()["profilePhoto"]
                          .toString(),
                      username:
                          snapshot.data!.docs[0].data()["username"].toString(),
                      followers:
                          snapshot.data!.docs[0].data()["followers"] as List,
                      following:
                          snapshot.data!.docs[0].data()["following"] as List,
                    );
                  }
                  return Container(
                    color: Theme.of(context).primaryColor,
                    child: Center(
                      child: Loader(),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class ProfileChild extends StatefulWidget {
  final String? name;
  final String? username;
  final String? id;
  final String? email;
  final String? userPhoto;
  final String? coverPhoto;
  final bool? premium;
  final bool? ownProfile;
  final Map? links;
  final String? bio;
  final List? followers;
  final List? following;
  const ProfileChild({
    required this.name,
    required this.username,
    required this.id,
    required this.email,
    required this.userPhoto,
    required this.coverPhoto,
    required this.premium,
    required this.ownProfile,
    required this.links,
    required this.bio,
    required this.followers,
    required this.following,
  });
  @override
  _ProfileChildState createState() => _ProfileChildState();
}

class _ProfileChildState extends State<ProfileChild> {
  // int favCount = main.prefs.get('userFavs') as int? ?? 0;
  // int profileCount = ((main.prefs.get('userPosts') as int?) ?? 0) +
  //     ((main.prefs.get('userSetups') as int?) ?? 0);
  final ScrollController scrollController = ScrollController();
  // final FirebaseFirestore firestore = FirebaseFirestore.instance;
  // int count = 0;
  @override
  void initState() {
    // count = main.prefs.get('easterCount', defaultValue: 0) as int;
    // checkFav();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController? controller = widget.ownProfile!
        ? InheritedDataProvider.of(context)!.scrollController
        : ScrollController();

    return !widget.ownProfile! || globals.prismUser.loggedIn
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
                        toolbarHeight: MediaQuery.of(context).padding.top +
                            kToolbarHeight +
                            32,
                        primary: false,
                        floating: true,
                        elevation: 0,
                        leading: !widget.ownProfile! ||
                                globals.prismUser.loggedIn == false
                            ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: IconButton(
                                    padding: const EdgeInsets.all(2),
                                    icon: Container(
                                      padding: const EdgeInsets.all(6.0),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.5),
                                      ),
                                      child: Icon(JamIcons.chevron_left,
                                          color: Theme.of(context).accentColor),
                                    ),
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      if (navStack.length > 1) {
                                        navStack.removeLast();
                                        if ((navStack.last == "Wallpaper") ||
                                            (navStack.last ==
                                                "Search Wallpaper") ||
                                            (navStack.last ==
                                                "SharedWallpaper") ||
                                            (navStack.last == "SetupView")) {}
                                      }
                                      debugPrint(navStack.toString());
                                    }),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: IconButton(
                                    padding: const EdgeInsets.all(2),
                                    icon: Container(
                                      padding: const EdgeInsets.all(6.0),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.5),
                                      ),
                                      child: Icon(JamIcons.pencil,
                                          color: Theme.of(context).accentColor),
                                    ),
                                    onPressed: () async {
                                      Navigator.pushNamed(
                                          context, editProfileRoute);
                                      // await showModalBottomSheet(
                                      //   isScrollControlled: true,
                                      //   context: context,
                                      //   builder: (context) =>
                                      //       const EditProfilePanel(),
                                      // );
                                    }),
                              ),
                        actions: !widget.ownProfile! ||
                                globals.prismUser.loggedIn == false
                            ? [
                                if (globals.prismUser.loggedIn == false)
                                  Container()
                                else
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: ((widget.followers ?? [])
                                            .contains(globals.prismUser.email))
                                        ? IconButton(
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.all(2),
                                            icon: Container(
                                              padding:
                                                  const EdgeInsets.all(6.0),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Theme.of(context)
                                                    .primaryColor
                                                    .withOpacity(0.5),
                                              ),
                                              child: Icon(JamIcons.user_remove,
                                                  color: Theme.of(context)
                                                      .accentColor),
                                            ),
                                            onPressed: () {
                                              unfollow(
                                                  widget.email!, widget.id!);
                                              toasts.error(
                                                  "Unfollowed ${widget.name}!");
                                            })
                                        : IconButton(
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.all(2),
                                            icon: Container(
                                              padding:
                                                  const EdgeInsets.all(6.0),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Theme.of(context)
                                                    .primaryColor
                                                    .withOpacity(0.5),
                                              ),
                                              child: Icon(JamIcons.user_plus,
                                                  color: Theme.of(context)
                                                      .accentColor),
                                            ),
                                            onPressed: () {
                                              follow(widget.email!, widget.id!);
                                              http.post(
                                                Uri.parse(
                                                  'https://fcm.googleapis.com/fcm/send',
                                                ),
                                                headers: <String, String>{
                                                  'Content-Type':
                                                      'application/json',
                                                  'Authorization':
                                                      'key=$fcmServerToken',
                                                },
                                                body: jsonEncode(
                                                  <String, dynamic>{
                                                    'notification':
                                                        <String, dynamic>{
                                                      'title':
                                                          '🎉 New Follower!',
                                                      'body':
                                                          '${globals.prismUser.username} is now following you.',
                                                      'color': "#e57697",
                                                      'tag':
                                                          '${globals.prismUser.username} Follow',
                                                      'image': globals.prismUser
                                                          .profilePhoto,
                                                      'android_channel_id':
                                                          "followers",
                                                      'icon':
                                                          '@drawable/ic_follow'
                                                    },
                                                    'priority': 'high',
                                                    'data': <String, dynamic>{
                                                      'click_action':
                                                          'FLUTTER_NOTIFICATION_CLICK',
                                                      'id': '1',
                                                      'status': 'done'
                                                    },
                                                    'to':
                                                        "/topics/${widget.email!.split("@")[0]}"
                                                  },
                                                ),
                                              );
                                              toasts.codeSend(
                                                  "Followed ${widget.name}!");
                                            }),
                                  )
                              ]
                            : [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: IconButton(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.all(2),
                                      icon: Container(
                                        padding: const EdgeInsets.all(6.0),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Theme.of(context)
                                              .primaryColor
                                              .withOpacity(0.5),
                                        ),
                                        child: Icon(JamIcons.menu,
                                            color:
                                                Theme.of(context).accentColor),
                                      ),
                                      onPressed: () {
                                        scaffoldKey.currentState!
                                            .openEndDrawer();
                                      }),
                                )
                              ],
                        backgroundColor: Theme.of(context).primaryColor,
                        automaticallyImplyLeading: false,
                        expandedHeight:
                            (widget.links ?? {}).keys.toList().isEmpty
                                ? MediaQuery.of(context).size.height * 0.4
                                : MediaQuery.of(context).size.height * 0.46,
                        flexibleSpace: Stack(
                          children: [
                            FlexibleSpaceBar(
                              background: Stack(
                                children: [
                                  Column(children: [
                                    if (widget.coverPhoto == null)
                                      SvgPicture.string(
                                        defaultHeader
                                            .replaceAll(
                                              "#181818",
                                              "#${Theme.of(context).primaryColor.value.toRadixString(16).toString().substring(2)}",
                                            )
                                            .replaceAll(
                                              "#E77597",
                                              "#${Theme.of(context).errorColor.value.toRadixString(16).toString().substring(2)}",
                                            ),
                                        fit: BoxFit.cover,
                                        width:
                                            MediaQuery.of(context).size.width,
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.19,
                                      )
                                    else
                                      CachedNetworkImage(
                                        imageUrl: widget.coverPhoto ??
                                            "https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Headers%2FheaderDefault.png?alt=media&token=1a10b128-c355-45d8-af96-678c13c05b3c",
                                        fit: BoxFit.cover,
                                        width:
                                            MediaQuery.of(context).size.width,
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.19,
                                      ),
                                    const SizedBox(
                                      width: double.maxFinite,
                                      height: 37,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.fromLTRB(
                                          12, 4, 12, 0),
                                      width: double.maxFinite,
                                      height: (widget.links ?? {})
                                              .keys
                                              .toList()
                                              .isEmpty
                                          ? MediaQuery.of(context).size.height *
                                                  0.21 -
                                              37
                                          : MediaQuery.of(context).size.height *
                                                  0.27 -
                                              37,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          SizedBox(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.7,
                                            child: Text(
                                              widget.name!,
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: "Proxima Nova",
                                                color: Theme.of(context)
                                                    .accentColor,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 2,
                                          ),
                                          SizedBox(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.7,
                                            child: Text(
                                              "@${widget.username}",
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: "Proxima Nova",
                                                color: Theme.of(context)
                                                    .accentColor
                                                    .withOpacity(0.6),
                                                fontSize: 16,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 15,
                                          ),
                                          SizedBox(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.7,
                                            child: Text(
                                              widget.bio ?? "",
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: "Proxima Nova",
                                                color: Theme.of(context)
                                                    .accentColor
                                                    .withOpacity(0.6),
                                                fontSize: 14,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 15,
                                          ),
                                          SizedBox(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.7,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                RichText(
                                                  text: TextSpan(
                                                    text:
                                                        "${(widget.following ?? []).length}",
                                                    style: TextStyle(
                                                      fontFamily:
                                                          "Proxima Nova",
                                                      color: Theme.of(context)
                                                          .accentColor
                                                          .withOpacity(1),
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    children: [
                                                      TextSpan(
                                                        text: " Following",
                                                        style: TextStyle(
                                                          color: Theme.of(
                                                                  context)
                                                              .accentColor
                                                              .withOpacity(0.6),
                                                          fontWeight:
                                                              FontWeight.normal,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(width: 24),
                                                RichText(
                                                  text: TextSpan(
                                                    text:
                                                        "${(widget.followers ?? []).length}",
                                                    style: TextStyle(
                                                      fontFamily:
                                                          "Proxima Nova",
                                                      color: Theme.of(context)
                                                          .accentColor
                                                          .withOpacity(1),
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    children: [
                                                      TextSpan(
                                                        text: " Followers",
                                                        style: TextStyle(
                                                          color: Theme.of(
                                                                  context)
                                                              .accentColor
                                                              .withOpacity(0.6),
                                                          fontWeight:
                                                              FontWeight.normal,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          if ((widget.links ?? {})
                                              .keys
                                              .toList()
                                              .isNotEmpty)
                                            const SizedBox(
                                              height: 8,
                                            ),
                                          if ((widget.links ?? {})
                                              .keys
                                              .toList()
                                              .isNotEmpty)
                                            SizedBox(
                                              width: MediaQuery.of(context)
                                                  .size
                                                  .width,
                                              height: 48,
                                              child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    ...(widget.links ?? {})
                                                        .keys
                                                        .toList()
                                                        .map((e) => IconButton(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(2),
                                                            icon: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(6.0),
                                                              decoration:
                                                                  BoxDecoration(
                                                                shape: BoxShape
                                                                    .circle,
                                                                color: Theme.of(
                                                                        context)
                                                                    .accentColor
                                                                    .withOpacity(
                                                                        0.1),
                                                              ),
                                                              child: Icon(
                                                                linksData[e]![
                                                                        "icon"]
                                                                    as IconData,
                                                                size: 20,
                                                                color: Theme.of(
                                                                        context)
                                                                    .accentColor
                                                                    .withOpacity(
                                                                        0.8),
                                                              ),
                                                            ),
                                                            onPressed: () {
                                                              if (widget
                                                                  .links![e]
                                                                  .toString()
                                                                  .contains(
                                                                      "@gmail.com")) {
                                                                launch(
                                                                    "mailto:${widget.links![e].toString()}");
                                                              } else {
                                                                launch(widget
                                                                    .links![e]
                                                                    .toString());
                                                              }
                                                            }))
                                                        .toList()
                                                        .sublist(
                                                          0,
                                                          (widget.links ?? {})
                                                                      .keys
                                                                      .toList()
                                                                      .length >
                                                                  3
                                                              ? 3
                                                              : (widget.links ??
                                                                      {})
                                                                  .keys
                                                                  .toList()
                                                                  .length,
                                                        ),
                                                    if ((widget.links ?? {})
                                                            .keys
                                                            .toList()
                                                            .length >
                                                        3)
                                                      IconButton(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(2),
                                                          icon: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(6.0),
                                                            decoration:
                                                                BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor
                                                                  .withOpacity(
                                                                      0.1),
                                                            ),
                                                            child: Icon(
                                                              JamIcons
                                                                  .more_horizontal,
                                                              size: 20,
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor
                                                                  .withOpacity(
                                                                      0.8),
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            showNoLoadLinksPopUp(
                                                                context,
                                                                widget.links ??
                                                                    {});
                                                          }),
                                                  ]),
                                            )
                                        ],
                                      ),
                                    )
                                  ]),
                                  Positioned(
                                    top: MediaQuery.of(context).size.height *
                                            0.19 -
                                        56,
                                    child: SizedBox(
                                      width: MediaQuery.of(context).size.width,
                                      child: Center(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color:
                                                  Theme.of(context).errorColor,
                                              width: 4,
                                            ),
                                            color:
                                                Theme.of(context).accentColor,
                                          ),
                                          child: ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl: widget.userPhoto ??
                                                  "".toString(),
                                              width: 78,
                                              height: 78,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Stack(
                              //   fit: StackFit.expand,
                              //   children: [
                              //     Container(
                              //       color: Theme.of(context).errorColor,
                              //     ),
                              //     Padding(
                              //       padding: const EdgeInsets.fromLTRB(
                              //           16, 25, 16, 0),
                              //       child: Column(
                              //         children: [
                              //           const Spacer(flex: 5),
                              //           Table(
                              //             columnWidths: const {
                              //               0: FlexColumnWidth(3),
                              //               1: FlexColumnWidth(5)
                              //             },
                              //             children: [
                              //               TableRow(children: [
                              //                 TableCell(
                              //                   child: Stack(
                              //                     alignment: Alignment.center,
                              //                     children: [
                              //                       Container(
                              //                         padding:
                              //                             const EdgeInsets.all(
                              //                                 0),
                              //                         decoration: BoxDecoration(
                              //                           color: Theme.of(context)
                              //                               .errorColor,
                              //                           borderRadius:
                              //                               BorderRadius
                              //                                   .circular(5000),
                              //                           boxShadow: [
                              //                             BoxShadow(
                              //                                 blurRadius: 16,
                              //                                 offset:
                              //                                     const Offset(
                              //                                         0, 4),
                              //                                 color: const Color(
                              //                                         0xFF000000)
                              //                                     .withOpacity(
                              //                                         0.24))
                              //                           ],
                              //                         ),
                              //                         child: CircleAvatar(
                              //                           backgroundColor:
                              //                               Colors.transparent,
                              //                           foregroundColor:
                              //                               Colors.transparent,
                              //                           radius: 50,
                              //                           child: ClipOval(
                              //                             child: Container(
                              //                               height: 120,
                              //                               margin:
                              //                                   const EdgeInsets
                              //                                       .all(0),
                              //                               padding:
                              //                                   const EdgeInsets
                              //                                       .all(0),
                              //                               child:
                              //                                   CachedNetworkImage(
                              //                                 fit: BoxFit.cover,
                              //                                 imageUrl: globals
                              //                                     .prismUser
                              //                                     .profilePhoto
                              //                                     .toString(),
                              //                                 errorWidget: (context,
                              //                                         url,
                              //                                         error) =>
                              //                                     Container(),
                              //                               ),
                              //                             ),
                              //                           ),
                              //                         ),
                              //                       ),
                              //                       if (globals.verifiedUsers
                              //                           .contains(globals
                              //                               .prismUser.email))
                              //                         Positioned(
                              //                           top: 5,
                              //                           left: 100,
                              //                           child: SizedBox(
                              //                             width: 30,
                              //                             height: 30,
                              //                             child: SvgPicture
                              //                                 .string(verifiedIcon
                              //                                     .replaceAll(
                              //                                         "E57697",
                              //                                         "FFFFFF")),
                              //                           ),
                              //                         )
                              //                       else
                              //                         Container(),
                              //                     ],
                              //                   ),
                              //                 ),
                              //                 TableCell(
                              //                   verticalAlignment:
                              //                       TableCellVerticalAlignment
                              //                           .bottom,
                              //                   child: Column(
                              //                     children: [
                              //                       Padding(
                              //                         padding:
                              //                             const EdgeInsets.only(
                              //                                 bottom: 5),
                              //                         child: globals.prismUser
                              //                                     .premium ==
                              //                                 false
                              //                             ? Text(
                              //                                 globals.prismUser
                              //                                     .username
                              //                                     .toUpperCase(),
                              //                                 textAlign:
                              //                                     TextAlign
                              //                                         .center,
                              //                                 style: TextStyle(
                              //                                     fontFamily:
                              //                                         "Proxima Nova",
                              //                                     color: Theme.of(
                              //                                             context)
                              //                                         .accentColor,
                              //                                     fontSize: 18,
                              //                                     fontWeight:
                              //                                         FontWeight
                              //                                             .w600),
                              //                               )
                              //                             : Row(
                              //                                 mainAxisAlignment:
                              //                                     MainAxisAlignment
                              //                                         .center,
                              //                                 crossAxisAlignment:
                              //                                     CrossAxisAlignment
                              //                                         .start,
                              //                                 children: <
                              //                                     Widget>[
                              //                                   Text(
                              //                                     globals
                              //                                         .prismUser
                              //                                         .username
                              //                                         .toUpperCase(),
                              //                                     style: TextStyle(
                              //                                         fontFamily:
                              //                                             "Proxima Nova",
                              //                                         color: Theme.of(
                              //                                                 context)
                              //                                             .accentColor,
                              //                                         fontSize:
                              //                                             18,
                              //                                         fontWeight:
                              //                                             FontWeight
                              //                                                 .w600),
                              //                                   ),
                              //                                   Padding(
                              //                                     padding: const EdgeInsets
                              //                                             .only(
                              //                                         left:
                              //                                             6.0),
                              //                                     child:
                              //                                         Container(
                              //                                       padding: const EdgeInsets
                              //                                               .symmetric(
                              //                                           vertical:
                              //                                               2,
                              //                                           horizontal:
                              //                                               4),
                              //                                       decoration:
                              //                                           BoxDecoration(
                              //                                         borderRadius:
                              //                                             BorderRadius.circular(
                              //                                                 50),
                              //                                         color: Theme.of(
                              //                                                 context)
                              //                                             .accentColor,
                              //                                       ),
                              //                                       child: Text(
                              //                                         "PRO",
                              //                                         style: Theme.of(
                              //                                                 context)
                              //                                             .textTheme
                              //                                             .bodyText2!
                              //                                             .copyWith(
                              //                                               fontSize:
                              //                                                   9,
                              //                                               color:
                              //                                                   Theme.of(context).errorColor,
                              //                                             ),
                              //                                       ),
                              //                                     ),
                              //                                   )
                              //                                 ],
                              //                               ),
                              //                       ),
                              //                       Padding(
                              //                         padding:
                              //                             const EdgeInsets.only(
                              //                                 bottom: 15),
                              //                         child: Text(
                              //                           globals.prismUser.bio,
                              //                           textAlign:
                              //                               TextAlign.center,
                              //                           maxLines: 3,
                              //                           overflow: TextOverflow
                              //                               .ellipsis,
                              //                         ),
                              //                       )
                              //                     ],
                              //                   ),
                              //                 ),
                              //               ]),
                              //               TableRow(children: [
                              //                 TableCell(
                              //                     verticalAlignment:
                              //                         TableCellVerticalAlignment
                              //                             .middle,
                              //                     child: Container()
                              //                     //ToDo Add link button in profile
                              //                     // IconButton(
                              //                     //     icon: Icon(
                              //                     //       JamIcons.link,
                              //                     //       color: Theme.of(context)
                              //                     //           .accentColor,
                              //                     //     ),
                              //                     //     onPressed: () {
                              //                     //       showLinksPopUp(context,
                              //                     //           globals.prismUser.id);
                              //                     //     }),
                              //                     ),
                              //                 TableCell(
                              //                   verticalAlignment:
                              //                       TableCellVerticalAlignment
                              //                           .middle,
                              //                   child: Row(
                              //                     mainAxisAlignment:
                              //                         MainAxisAlignment
                              //                             .spaceEvenly,
                              //                     children: <Widget>[
                              //                       GestureDetector(
                              //                         onTap: () {
                              //                           Navigator.pushNamed(
                              //                               context,
                              //                               favWallRoute);
                              //                         },
                              //                         child: Row(
                              //                           children: <Widget>[
                              //                             Text(
                              //                               "${favCount.toString()} ",
                              //                               style: TextStyle(
                              //                                   fontFamily:
                              //                                       "Proxima Nova",
                              //                                   fontSize: 22,
                              //                                   color: Theme.of(
                              //                                           context)
                              //                                       .accentColor,
                              //                                   fontWeight:
                              //                                       FontWeight
                              //                                           .normal),
                              //                             ),
                              //                             Icon(
                              //                               JamIcons.heart_f,
                              //                               size: 20,
                              //                               color: Theme.of(
                              //                                       context)
                              //                                   .accentColor,
                              //                             ),
                              //                           ],
                              //                         ),
                              //                       ),
                              //                       // Row(
                              //                       //   children: <Widget>[
                              //                       //     FutureBuilder(
                              //                       //         future: Provider.of<
                              //                       //                     ProfileWallProvider>(
                              //                       //                 context,
                              //                       //                 listen:
                              //                       //                     false)
                              //                       //             .getProfileWallsLength(),
                              //                       //         builder: (context,
                              //                       //             snapshot) {
                              //                       //           return Text(
                              //                       //             snapshot.data ==
                              //                       //                     null
                              //                       //                 ? "${profileCount.toString()} "
                              //                       //                 : "${snapshot.data.toString()} ",
                              //                       //             style: TextStyle(
                              //                       //                 fontFamily:
                              //                       //                     "Proxima Nova",
                              //                       //                 fontSize:
                              //                       //                     22,
                              //                       //                 color: Theme.of(
                              //                       //                         context)
                              //                       //                     .accentColor,
                              //                       //                 fontWeight:
                              //                       //                     FontWeight
                              //                       //                         .normal),
                              //                       //           );
                              //                       //         }),
                              //                       //     Icon(
                              //                       //       JamIcons.upload,
                              //                       //       size: 20,
                              //                       //       color:
                              //                       //           Theme.of(context)
                              //                       //               .accentColor,
                              //                       //     ),
                              //                       //   ],
                              //                       // ),
                              //                       StreamBuilder<
                              //                               QuerySnapshot>(
                              //                           stream: users
                              //                               .where("email",
                              //                                   isEqualTo: globals
                              //                                       .prismUser
                              //                                       .email)
                              //                               .snapshots(),
                              //                           builder: (BuildContext
                              //                                   context,
                              //                               AsyncSnapshot<
                              //                                       QuerySnapshot>
                              //                                   snapshot) {
                              //                             if (!snapshot
                              //                                 .hasData) {
                              //                               return Row(
                              //                                 children: [
                              //                                   Text(
                              //                                     "0",
                              //                                     style: TextStyle(
                              //                                         fontFamily:
                              //                                             "Proxima Nova",
                              //                                         fontSize:
                              //                                             22,
                              //                                         color: Theme.of(
                              //                                                 context)
                              //                                             .accentColor,
                              //                                         fontWeight:
                              //                                             FontWeight
                              //                                                 .normal),
                              //                                   ),
                              //                                   Icon(
                              //                                     JamIcons
                              //                                         .users,
                              //                                     size: 20,
                              //                                     color: Theme.of(
                              //                                             context)
                              //                                         .accentColor,
                              //                                   ),
                              //                                 ],
                              //                               );
                              //                             } else {
                              //                               List followers = [];
                              //                               if (snapshot.data!
                              //                                           .docs !=
                              //                                       null &&
                              //                                   snapshot
                              //                                       .data!
                              //                                       .docs
                              //                                       .isNotEmpty) {
                              //                                 followers = snapshot
                              //                                             .data!
                              //                                             .docs[0]
                              //                                             .data()['followers']
                              //                                         as List? ??
                              //                                     [];
                              //                               }
                              //                               return GestureDetector(
                              //                                 onTap: () {
                              //                                   // Navigator.pushNamed(
                              //                                   //     context,
                              //                                   //     followersRoute,
                              //                                   //     arguments: [
                              //                                   //       followers
                              //                                   //     ]);
                              //                                 },
                              //                                 child: Row(
                              //                                   children: [
                              //                                     Text(
                              //                                       followers.length >
                              //                                               1000
                              //                                           ? NumberFormat
                              //                                                   .compactCurrency(
                              //                                               decimalDigits:
                              //                                                   2,
                              //                                               symbol:
                              //                                                   '',
                              //                                             )
                              //                                               .format(followers
                              //                                                   .length)
                              //                                               .toString()
                              //                                           : followers
                              //                                               .length
                              //                                               .toString(),
                              //                                       style: TextStyle(
                              //                                           fontFamily:
                              //                                               "Proxima Nova",
                              //                                           fontSize:
                              //                                               22,
                              //                                           color: Theme.of(context)
                              //                                               .accentColor,
                              //                                           fontWeight:
                              //                                               FontWeight.normal),
                              //                                     ),
                              //                                     Icon(
                              //                                       JamIcons
                              //                                           .users,
                              //                                       size: 20,
                              //                                       color: Theme.of(
                              //                                               context)
                              //                                           .accentColor,
                              //                                     ),
                              //                                   ],
                              //                                 ),
                              //                               );
                              //                             }
                              //                           }),
                              //                     ],
                              //                   ),
                              //                 ),
                              //               ]),
                              //             ],
                              //           ),
                              //         ],
                              //       ),
                              //     ),
                              //   ],
                              // ),
                            ),
                            Container(
                              width: double.maxFinite,
                              height: MediaQuery.of(context).padding.top,
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                      SliverAppBar(
                        backgroundColor: Theme.of(context).primaryColor,
                        automaticallyImplyLeading: false,
                        pinned: true,
                        titleSpacing: 0,
                        expandedHeight:
                            !widget.ownProfile! || globals.prismUser.loggedIn
                                ? 50
                                : 0,
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
                                    Text(
                                      "Wallpapers",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyText2!
                                          .copyWith(
                                              color: Theme.of(context)
                                                  .accentColor),
                                    ),
                                    Text(
                                      "Setups",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyText2!
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
                        child: UserProfileLoader(
                          email: widget.email,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: UserProfileSetupLoader(
                          email: widget.email,
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ))
        : Scaffold(
            backgroundColor: Theme.of(context).primaryColor,
            body: CustomScrollView(controller: controller, slivers: <Widget>[
              SliverAppBar(
                backgroundColor: Theme.of(context).errorColor,
                automaticallyImplyLeading: false,
                expandedHeight: 280.0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Stack(
                        children: <Widget>[
                          Container(
                            color: Theme.of(context).errorColor,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                            child: Center(
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width / 2,
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
                AboutList(),
                const SizedBox(
                  height: 300,
                ),
              ]))
            ]),
          );
  }
}

Map<String, Map<String, dynamic>> linksData = {
  'github': {
    'name': 'github',
    'link': 'https://github.com/username',
    'icon': JamIcons.github,
    'value': '',
    'validator': 'github',
  },
  'twitter': {
    'name': 'twitter',
    'link': 'https://twitter.com/username',
    'icon': JamIcons.twitter,
    'value': '',
    'validator': 'twitter',
  },
  'instagram': {
    'name': 'instagram',
    'link': 'https://instagram.com/username',
    'icon': JamIcons.instagram,
    'value': '',
    'validator': 'instagram',
  },
  'email': {
    'name': 'email',
    'link': 'your@email.com',
    'icon': JamIcons.inbox,
    'value': '',
    'validator': '@',
  },
  'telegram': {
    'name': 'telegram',
    'link': 'https://t.me/username',
    'icon': JamIcons.paper_plane,
    'value': '',
    'validator': 't.me',
  },
  'dribbble': {
    'name': 'dribbble',
    'link': 'https://dribbble.com/username',
    'icon': JamIcons.basketball,
    'value': '',
    'validator': 'dribbble',
  },
  'linkedin': {
    'name': 'linkedin',
    'link': 'https://linkedin.com/in/username',
    'icon': JamIcons.linkedin,
    'value': '',
    'validator': 'linkedin',
  },
  'bio.link': {
    'name': 'bio.link',
    'link': 'https://bio.link/username',
    'icon': JamIcons.world,
    'value': '',
    'validator': 'bio.link',
  },
  'patreon': {
    'name': 'patreon',
    'link': 'https://patreon.com/username',
    'icon': JamIcons.patreon,
    'value': '',
    'validator': 'patreon',
  },
  'trello': {
    'name': 'trello',
    'link': 'https://trello.com/username',
    'icon': JamIcons.trello,
    'value': '',
    'validator': 'trello',
  },
  'reddit': {
    'name': 'reddit',
    'link': 'https://reddit.com/user/username',
    'icon': JamIcons.reddit,
    'value': '',
    'validator': 'reddit',
  },
  'behance': {
    'name': 'behance',
    'link': 'https://behance.net/username',
    'icon': JamIcons.behance,
    'value': '',
    'validator': 'behance.net',
  },
  'deviantart': {
    'name': 'deviantart',
    'link': 'https://deviantart.com/username',
    'icon': JamIcons.deviantart,
    'value': '',
    'validator': 'deviantart',
  },
  'gitlab': {
    'name': 'gitlab',
    'link': 'https://gitlab.com/username',
    'icon': JamIcons.gitlab,
    'value': '',
    'validator': 'gitlab',
  },
  'medium': {
    'name': 'medium',
    'link': 'https://username.medium.com/',
    'icon': JamIcons.medium,
    'value': '',
    'validator': 'medium',
  },
  'paypal': {
    'name': 'paypal',
    'link': 'https://paypal.me/username',
    'icon': JamIcons.paypal,
    'value': '',
    'validator': 'paypal',
  },
  'spotify': {
    'name': 'spotify',
    'link': 'https://open.spotify.com/user/username',
    'icon': JamIcons.spotify,
    'value': '',
    'validator': 'open.spotify',
  },
  'twitch': {
    'name': 'twitch',
    'link': 'https://twitch.tv/username',
    'icon': JamIcons.twitch,
    'value': '',
    'validator': 'twitch.tv',
  },
  'unsplash': {
    'name': 'unsplash',
    'link': 'https://unsplash.com/username',
    'icon': JamIcons.unsplash,
    'value': '',
    'validator': 'unsplash',
  },
  'youtube': {
    'name': 'youtube',
    'link': 'https://youtube.com/channel/username',
    'icon': JamIcons.youtube,
    'value': '',
    'validator': 'youtube',
  },
  'linktree': {
    'name': 'linktree',
    'link': 'https://linktr.ee/username',
    'icon': JamIcons.tree_alt,
    'value': '',
    'validator': 'linktr.ee',
  },
  'buymeacoffee': {
    'name': 'buymeacoffee',
    'link': 'https://buymeacoff.ee/username',
    'icon': JamIcons.coffee,
    'value': '',
    'validator': 'buymeacoff.ee',
  },
  'custom link': {
    'name': 'custom link',
    'link': '',
    'icon': JamIcons.link,
    'value': '',
    'validator': '',
  },
};
