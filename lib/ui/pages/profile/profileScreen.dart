import 'dart:async';
import 'dart:math';
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/data/favourites/provider/favouriteSetupProvider.dart';
import 'package:Prism/data/profile/wallpaper/getUserProfile.dart';
import 'package:Prism/data/profile/wallpaper/profileSetupProvider.dart';
import 'package:Prism/data/profile/wallpaper/profileWallProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/ui/widgets/popup/linkPopUp.dart';
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
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/global/globals.dart' as globals;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
            width: MediaQuery.of(context).size.width * 0.68,
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
  late ConfettiController _controllerBottomCenter;
  int favCount = main.prefs.get('userFavs') as int? ?? 0;
  int profileCount = ((main.prefs.get('userPosts') as int?) ?? 0) +
      ((main.prefs.get('userSetups') as int?) ?? 0);
  final ScrollController scrollController = ScrollController();
  final Firestore firestore = Firestore.instance;
  int count = 0;
  @override
  void initState() {
    count = main.prefs.get('easterCount', defaultValue: 0) as int;
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
    if (globals.prismUser.loggedIn) {
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
    final ScrollController? controller =
        InheritedDataProvider.of(context)!.scrollController;
    final CollectionReference users = firestore.collection('users');

    return WillPopScope(
        onWillPop: onWillPop,
        child: globals.prismUser.loggedIn
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
                            actions: globals.prismUser.loggedIn == false
                                ? []
                                : [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: IconButton(
                                          icon: Icon(JamIcons.menu,
                                              color: Theme.of(context)
                                                  .accentColor),
                                          onPressed: () {
                                            scaffoldKey.currentState!
                                                .openEndDrawer();
                                          }),
                                    )
                                  ],
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
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    Container(
                                                      decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
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
                                                      child: GestureDetector(
                                                        onTap: () {
                                                          _controllerBottomCenter
                                                              .play();
                                                          count++;
                                                          main.prefs.put(
                                                              'easterCount',
                                                              count);
                                                          if ((main.prefs.get(
                                                                  'easterCount',
                                                                  defaultValue:
                                                                      0) as int) >
                                                              20) {
                                                            toasts.codeSend(
                                                                "Congratulations");
                                                            firestore
                                                                .collection(
                                                                    "easter")
                                                                .add({
                                                              "name": globals
                                                                  .prismUser
                                                                  .username,
                                                              "email": globals
                                                                  .prismUser
                                                                  .email,
                                                              "userPhoto": globals
                                                                  .prismUser
                                                                  .profilePhoto,
                                                            });
                                                          }
                                                        },
                                                        child: CircleAvatar(
                                                          radius: 50,
                                                          backgroundImage:
                                                              NetworkImage(globals
                                                                  .prismUser
                                                                  .profilePhoto
                                                                  .toString()),
                                                        ),
                                                      ),
                                                    ),
                                                    if (globals.verifiedUsers
                                                        .contains(globals
                                                            .prismUser.email))
                                                      Positioned(
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
                                                    else
                                                      Container(),
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
                                                  child: globals.prismUser
                                                              .premium ==
                                                          false
                                                      ? Text(
                                                          globals.prismUser
                                                              .username
                                                              .toUpperCase(),
                                                          textAlign:
                                                              TextAlign.center,
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
                                                          children: <Widget>[
                                                            Text(
                                                              globals.prismUser
                                                                  .username
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
                                                                      left:
                                                                          6.0),
                                                              child: Container(
                                                                padding: const EdgeInsets
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
                                                                      .bodyText2!
                                                                      .copyWith(
                                                                        fontSize:
                                                                            9,
                                                                        color: Theme.of(context)
                                                                            .errorColor,
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
                                                child: IconButton(
                                                    icon: Icon(
                                                      JamIcons.link,
                                                      color: Theme.of(context)
                                                          .accentColor,
                                                    ),
                                                    onPressed: () {
                                                      showLinksPopUp(context,
                                                          globals.prismUser.id);
                                                    }),
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
                                                    GestureDetector(
                                                      onTap: () {
                                                        Navigator.pushNamed(
                                                            context,
                                                            favWallRoute);
                                                      },
                                                      child: Row(
                                                        children: <Widget>[
                                                          Text(
                                                            "${favCount.toString()} ",
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
                                                            JamIcons.heart_f,
                                                            size: 20,
                                                            color: Theme.of(
                                                                    context)
                                                                .accentColor,
                                                          ),
                                                        ],
                                                      ),
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
                                                                        22,
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
                                                          size: 20,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                        ),
                                                      ],
                                                    ),
                                                    StreamBuilder<
                                                            QuerySnapshot>(
                                                        stream: users
                                                            .where("email",
                                                                isEqualTo: globals
                                                                    .prismUser
                                                                    .email)
                                                            .snapshots(),
                                                        builder: (BuildContext
                                                                context,
                                                            AsyncSnapshot<
                                                                    QuerySnapshot>
                                                                snapshot) {
                                                          if (!snapshot
                                                              .hasData) {
                                                            return Row(
                                                              children: [
                                                                Text(
                                                                  "0",
                                                                  style: TextStyle(
                                                                      fontFamily:
                                                                          "Proxima Nova",
                                                                      fontSize:
                                                                          22,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .accentColor,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .normal),
                                                                ),
                                                                Icon(
                                                                  JamIcons
                                                                      .users,
                                                                  size: 20,
                                                                  color: Theme.of(
                                                                          context)
                                                                      .accentColor,
                                                                ),
                                                              ],
                                                            );
                                                          } else {
                                                            List followers = [];
                                                            if (snapshot.data!
                                                                        .documents !=
                                                                    null &&
                                                                snapshot
                                                                    .data!
                                                                    .documents
                                                                    .isNotEmpty) {
                                                              followers = snapshot
                                                                          .data!
                                                                          .documents[
                                                                              0]
                                                                          .data['followers']
                                                                      as List? ??
                                                                  [];
                                                            }
                                                            return GestureDetector(
                                                              onTap: () {
                                                                Navigator.pushNamed(
                                                                    context,
                                                                    followersRoute,
                                                                    arguments: [
                                                                      followers
                                                                    ]);
                                                              },
                                                              child: Row(
                                                                children: [
                                                                  Text(
                                                                    followers
                                                                        .length
                                                                        .toString(),
                                                                    style: TextStyle(
                                                                        fontFamily:
                                                                            "Proxima Nova",
                                                                        fontSize:
                                                                            22,
                                                                        color: Theme.of(context)
                                                                            .accentColor,
                                                                        fontWeight:
                                                                            FontWeight.normal),
                                                                  ),
                                                                  Icon(
                                                                    JamIcons
                                                                        .users,
                                                                    size: 20,
                                                                    color: Theme.of(
                                                                            context)
                                                                        .accentColor,
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          }
                                                        }),
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
                            backgroundColor: Theme.of(context).errorColor,
                            automaticallyImplyLeading: false,
                            pinned: true,
                            titleSpacing: 0,
                            expandedHeight: globals.prismUser.loggedIn ? 50 : 0,
                            title: SizedBox(
                              width: MediaQuery.of(context).size.width,
                              height: 57,
                              child: Container(
                                color: Theme.of(context).errorColor,
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
                    // const StudioList(),
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
