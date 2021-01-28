import 'package:flutter/material.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/home/core/headingChipBar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/main.dart' as main;
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/services.dart';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/theme/config.dart' as config;
import 'package:animations/animations.dart';

class ReviewScreen extends StatefulWidget {
  @override
  _ReviewScreenState createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen>
    with SingleTickerProviderStateMixin {
  TabController tabController;
  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  @override
  void initState() {
    tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: const PreferredSize(
            preferredSize: Size(double.infinity, 55),
            child: HeadingChipBar(
              current: "Review Status",
            ),
          ),
          bottom: TabBar(
              controller: tabController,
              indicatorColor: Theme.of(context).accentColor,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(
                  child: Text(
                    "Wallpapers",
                    style: Theme.of(context)
                        .textTheme
                        .bodyText2
                        .copyWith(color: Theme.of(context).accentColor),
                  ),
                ),
                Tab(
                  child: Text(
                    "Setups",
                    style: Theme.of(context)
                        .textTheme
                        .bodyText2
                        .copyWith(color: Theme.of(context).accentColor),
                  ),
                )
              ]),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        body: TabBarView(
          controller: tabController,
          children: [
            WallReview(),
            SetupReview(),
          ],
        ),
      ),
    );
  }
}

class WallReview extends StatefulWidget {
  @override
  _WallReviewState createState() => _WallReviewState();
}

class _WallReviewState extends State<WallReview> {
  Firestore firestore = Firestore.instance;
  @override
  Widget build(BuildContext context) {
    CollectionReference walls = firestore.collection('walls');
    CollectionReference rejectedWalls = firestore.collection('rejectedWalls');
    return SingleChildScrollView(
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
              stream: rejectedWalls
                  .where("email", isEqualTo: main.prefs.get('email').toString())
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: Loader(),
                  );
                } else {
                  return Column(
                    children: List.generate(
                      snapshot.data.documents.length,
                      (int index) =>
                          RejectedWallTile(snapshot.data.documents[index]),
                    ),
                  );
                }
              }),
          StreamBuilder<QuerySnapshot>(
              stream: walls
                  .where("email", isEqualTo: main.prefs.get('email').toString())
                  .where("review", isEqualTo: false)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: Loader(),
                  );
                } else {
                  return Column(
                    children: List.generate(
                      snapshot.data.documents.length,
                      (int index) => WallTile(snapshot.data.documents[index]),
                    ),
                  );
                }
              }),
        ],
      ),
    );
  }
}

class WallTile extends StatelessWidget {
  final DocumentSnapshot wallpaper;
  WallTile(this.wallpaper);
  final DateFormat formatter = DateFormat('d MMMM y, h:m a');
  static const platform = MethodChannel('flutter.prism.set_wallpaper');
  Firestore firestore = Firestore.instance;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 340,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        color: Theme.of(context).primaryColor,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: Theme.of(context).accentColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        JamIcons.clock,
                        color: Theme.of(context).accentColor,
                      ),
                      SizedBox(
                        width: 8,
                      ),
                      Text(
                        "${formatter.format((wallpaper.data["createdAt"] as Timestamp).toDate().toLocal())}",
                        style: Theme.of(context)
                            .textTheme
                            .bodyText2
                            .copyWith(color: Theme.of(context).accentColor),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                CupertinoPageRoute(
                                    builder: (context) => PhotoView(
                                          onTapUp:
                                              (context, details, controller) {
                                            Navigator.pop(context);
                                          },
                                          imageProvider:
                                              CachedNetworkImageProvider(
                                            wallpaper.data["wallpaper_url"]
                                                as String,
                                          ),
                                        ),
                                    fullscreenDialog: true));
                          },
                          child: SizedBox(
                            height: 240,
                            width: 120,
                            child: CachedNetworkImage(
                              imageUrl:
                                  wallpaper.data["wallpaper_thumb"] as String,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 32,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  JamIcons.id_card,
                                  color: Theme.of(context).accentColor,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  "${wallpaper.data["id"]}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .copyWith(
                                          color: Theme.of(context).accentColor),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            Row(
                              children: [
                                Icon(
                                  JamIcons.save,
                                  color: Theme.of(context).accentColor,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  "${wallpaper.data["size"]}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .copyWith(
                                          color: Theme.of(context).accentColor),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            Row(
                              children: [
                                Icon(
                                  JamIcons.set_square,
                                  color: Theme.of(context).accentColor,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  "${wallpaper.data["resolution"]}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .copyWith(
                                          color: Theme.of(context).accentColor),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            ActionChip(
                              backgroundColor: Colors.amber,
                              avatar: Icon(
                                JamIcons.clock,
                                color: Colors.black,
                              ),
                              onPressed: () {},
                              label: Text(
                                "IN REVIEW",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText2
                                    .copyWith(color: Colors.black),
                              ),
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(JamIcons.download,
                                        color: Theme.of(context).primaryColor),
                                    onPressed: () async {
                                      final status =
                                          await Permission.storage.status;
                                      if (!status.isGranted) {
                                        await Permission.storage.request();
                                      }
                                      final link = wallpaper
                                          .data["wallpaper_url"]
                                          .toString();
                                      debugPrint(link);

                                      final androidInfo =
                                          await DeviceInfoPlugin().androidInfo;
                                      final sdkInt = androidInfo.version.sdkInt;
                                      debugPrint('(SDK $sdkInt)');
                                      toasts.codeSend("Starting Download");

                                      if (sdkInt >= 30) {
                                        await platform.invokeMethod(
                                            'save_image',
                                            {"link": link}).then((value) {
                                          if (value as bool) {
                                            analytics.logEvent(
                                                name: 'download_own_wall',
                                                parameters: {'link': link});
                                            toasts.codeSend(
                                                "Wall Downloaded in Pictures/Prism!");
                                          } else {
                                            toasts.error(
                                                "Couldn't download! Please Retry!");
                                          }
                                        }).catchError((e) {
                                          debugPrint(e.toString());
                                        });
                                      } else {
                                        GallerySaver.saveImage(link,
                                                albumName: "Prism")
                                            .then((value) {
                                          analytics.logEvent(
                                              name: 'download_own_wall',
                                              parameters: {'link': link});
                                          toasts.codeSend(
                                              "Wall Downloaded in Internal Storage/Prism!");
                                        }).catchError((e) {});
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 16,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(JamIcons.trash,
                                        color: Colors.white),
                                    onPressed: () async {
                                      final AlertDialog deleteWallPopUp =
                                          AlertDialog(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        title: Text(
                                          'Delete this wallpaper?',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              color: Theme.of(context)
                                                  .accentColor),
                                        ),
                                        content: Text(
                                          "This is permanent, and this action can't be undone!",
                                          style: TextStyle(
                                              fontFamily: "Proxima Nova",
                                              fontWeight: FontWeight.normal,
                                              fontSize: 14,
                                              color: Theme.of(context)
                                                  .accentColor),
                                        ),
                                        actions: [
                                          FlatButton(
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5)),
                                            color: Theme.of(context).hintColor,
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              await firestore
                                                  .collection("walls")
                                                  .document(
                                                      wallpaper.documentID)
                                                  .delete();
                                              toasts.codeSend(
                                                  "Wallpaper successfully deleted from server!");
                                            },
                                            child: const Text(
                                              'DELETE',
                                              style: TextStyle(
                                                fontSize: 16.0,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          FlatButton(
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5)),
                                            color: config.Colors()
                                                .mainAccentColor(1),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text(
                                              'CANCEL',
                                              style: TextStyle(
                                                fontSize: 16.0,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                        backgroundColor:
                                            Theme.of(context).primaryColor,
                                        actionsPadding:
                                            const EdgeInsets.fromLTRB(
                                                10, 0, 10, 0),
                                      );

                                      showModal(
                                          context: context,
                                          configuration:
                                              const FadeScaleTransitionConfiguration(),
                                          builder: (BuildContext context) =>
                                              deleteWallPopUp);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                        // Text(
                        //   "${formatter.format((wallpaper.data["createdAt"] as Timestamp).toDate().toLocal())}",
                        //   style: Theme.of(context)
                        //       .textTheme
                        //       .bodyText2
                        //       .copyWith(color: Theme.of(context).accentColor),
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RejectedWallTile extends StatelessWidget {
  final DocumentSnapshot wallpaper;
  RejectedWallTile(this.wallpaper);
  final DateFormat formatter = DateFormat('d MMMM y, h:m a');
  static const platform = MethodChannel('flutter.prism.set_wallpaper');
  Firestore firestore = Firestore.instance;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 400,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        color: Theme.of(context).primaryColor,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: Theme.of(context).accentColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        JamIcons.clock,
                        color: Theme.of(context).accentColor,
                      ),
                      SizedBox(
                        width: 8,
                      ),
                      Text(
                        "${formatter.format((wallpaper.data["createdAt"] as Timestamp).toDate().toLocal())}",
                        style: Theme.of(context)
                            .textTheme
                            .bodyText2
                            .copyWith(color: Theme.of(context).accentColor),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                CupertinoPageRoute(
                                    builder: (context) => PhotoView(
                                          onTapUp:
                                              (context, details, controller) {
                                            Navigator.pop(context);
                                          },
                                          imageProvider:
                                              CachedNetworkImageProvider(
                                            wallpaper.data["wallpaper_url"]
                                                as String,
                                          ),
                                        ),
                                    fullscreenDialog: true));
                          },
                          child: SizedBox(
                            height: 240,
                            width: 120,
                            child: CachedNetworkImage(
                              imageUrl:
                                  wallpaper.data["wallpaper_thumb"] as String,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 32,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  JamIcons.id_card,
                                  color: Theme.of(context).accentColor,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  "${wallpaper.data["id"]}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .copyWith(
                                          color: Theme.of(context).accentColor),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            Row(
                              children: [
                                Icon(
                                  JamIcons.save,
                                  color: Theme.of(context).accentColor,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  "${wallpaper.data["size"]}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .copyWith(
                                          color: Theme.of(context).accentColor),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            Row(
                              children: [
                                Icon(
                                  JamIcons.set_square,
                                  color: Theme.of(context).accentColor,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  "${wallpaper.data["resolution"]}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .copyWith(
                                          color: Theme.of(context).accentColor),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            ActionChip(
                              backgroundColor: Colors.red,
                              avatar: Icon(
                                JamIcons.close,
                                color: Colors.white,
                              ),
                              onPressed: () {},
                              label: Text(
                                "REJECTED",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText2
                                    .copyWith(color: Colors.white),
                              ),
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(JamIcons.download,
                                        color: Theme.of(context).primaryColor),
                                    onPressed: () async {
                                      final status =
                                          await Permission.storage.status;
                                      if (!status.isGranted) {
                                        await Permission.storage.request();
                                      }
                                      final link = wallpaper
                                          .data["wallpaper_url"]
                                          .toString();
                                      debugPrint(link);

                                      final androidInfo =
                                          await DeviceInfoPlugin().androidInfo;
                                      final sdkInt = androidInfo.version.sdkInt;
                                      debugPrint('(SDK $sdkInt)');
                                      toasts.codeSend("Starting Download");

                                      if (sdkInt >= 30) {
                                        await platform.invokeMethod(
                                            'save_image',
                                            {"link": link}).then((value) {
                                          if (value as bool) {
                                            analytics.logEvent(
                                                name: 'download_own_wall',
                                                parameters: {'link': link});
                                            toasts.codeSend(
                                                "Wall Downloaded in Pictures/Prism!");
                                          } else {
                                            toasts.error(
                                                "Couldn't download! Please Retry!");
                                          }
                                        }).catchError((e) {
                                          debugPrint(e.toString());
                                        });
                                      } else {
                                        GallerySaver.saveImage(link,
                                                albumName: "Prism")
                                            .then((value) {
                                          analytics.logEvent(
                                              name: 'download_own_wall',
                                              parameters: {'link': link});
                                          toasts.codeSend(
                                              "Wall Downloaded in Internal Storage/Prism!");
                                        }).catchError((e) {});
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 16,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(JamIcons.trash,
                                        color: Colors.white),
                                    onPressed: () async {
                                      final AlertDialog deleteWallPopUp =
                                          AlertDialog(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        title: Text(
                                          'Delete this wallpaper?',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              color: Theme.of(context)
                                                  .accentColor),
                                        ),
                                        content: Text(
                                          "This is permanent, and this action can't be undone!",
                                          style: TextStyle(
                                              fontFamily: "Proxima Nova",
                                              fontWeight: FontWeight.normal,
                                              fontSize: 14,
                                              color: Theme.of(context)
                                                  .accentColor),
                                        ),
                                        actions: [
                                          FlatButton(
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5)),
                                            color: Theme.of(context).hintColor,
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              await firestore
                                                  .collection("rejectedWalls")
                                                  .document(
                                                      wallpaper.documentID)
                                                  .delete();
                                              toasts.codeSend(
                                                  "Wallpaper successfully deleted from server!");
                                            },
                                            child: const Text(
                                              'DELETE',
                                              style: TextStyle(
                                                fontSize: 16.0,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          FlatButton(
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5)),
                                            color: config.Colors()
                                                .mainAccentColor(1),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text(
                                              'CANCEL',
                                              style: TextStyle(
                                                fontSize: 16.0,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                        backgroundColor:
                                            Theme.of(context).primaryColor,
                                        actionsPadding:
                                            const EdgeInsets.fromLTRB(
                                                10, 0, 10, 0),
                                      );

                                      showModal(
                                          context: context,
                                          configuration:
                                              const FadeScaleTransitionConfiguration(),
                                          builder: (BuildContext context) =>
                                              deleteWallPopUp);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                        // Text(
                        //   "${formatter.format((wallpaper.data["createdAt"] as Timestamp).toDate().toLocal())}",
                        //   style: Theme.of(context)
                        //       .textTheme
                        //       .bodyText2
                        //       .copyWith(color: Theme.of(context).accentColor),
                        // ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        JamIcons.close,
                        color: Theme.of(context).accentColor,
                      ),
                      SizedBox(
                        width: 8,
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.7,
                        child: Text(
                          "The wallpaper didn't meet our expectations. Please try uploading a good quality wallpaper.",
                          style: Theme.of(context)
                              .textTheme
                              .bodyText2
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SetupReview extends StatefulWidget {
  @override
  _SetupReviewState createState() => _SetupReviewState();
}

class _SetupReviewState extends State<SetupReview> {
  Firestore firestore = Firestore.instance;
  @override
  Widget build(BuildContext context) {
    CollectionReference setups = firestore.collection('setups');
    CollectionReference rejectedSetups = firestore.collection('rejectedSetups');
    return SingleChildScrollView(
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
              stream: rejectedSetups
                  .where("email", isEqualTo: main.prefs.get('email').toString())
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: Loader(),
                  );
                } else {
                  return Column(
                    children: List.generate(
                      snapshot.data.documents.length,
                      (int index) =>
                          RejectedSetupTile(snapshot.data.documents[index]),
                    ),
                  );
                }
              }),
          StreamBuilder<QuerySnapshot>(
              stream: setups
                  .where("email", isEqualTo: main.prefs.get('email').toString())
                  .where("review", isEqualTo: false)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: Loader(),
                  );
                } else {
                  return Column(
                    children: List.generate(
                      snapshot.data.documents.length,
                      (int index) => SetupTile(snapshot.data.documents[index]),
                    ),
                  );
                }
              }),
        ],
      ),
    );
  }
}

class SetupTile extends StatelessWidget {
  final DocumentSnapshot wallpaper;
  SetupTile(this.wallpaper);
  final DateFormat formatter = DateFormat('d MMMM y, h:m a');
  static const platform = MethodChannel('flutter.prism.set_wallpaper');
  Firestore firestore = Firestore.instance;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 340,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        color: Theme.of(context).primaryColor,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: Theme.of(context).accentColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        JamIcons.clock,
                        color: Theme.of(context).accentColor,
                      ),
                      SizedBox(
                        width: 8,
                      ),
                      Text(
                        "${formatter.format((wallpaper.data["created_at"] as Timestamp).toDate().toLocal())}",
                        style: Theme.of(context)
                            .textTheme
                            .bodyText2
                            .copyWith(color: Theme.of(context).accentColor),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                CupertinoPageRoute(
                                    builder: (context) => PhotoView(
                                          onTapUp:
                                              (context, details, controller) {
                                            Navigator.pop(context);
                                          },
                                          imageProvider:
                                              CachedNetworkImageProvider(
                                            wallpaper.data["image"] as String,
                                          ),
                                        ),
                                    fullscreenDialog: true));
                          },
                          child: SizedBox(
                            height: 240,
                            width: 120,
                            child: CachedNetworkImage(
                              imageUrl: wallpaper.data["image"] as String,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 32,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  JamIcons.id_card,
                                  color: Theme.of(context).accentColor,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  "${wallpaper.data["id"]}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .copyWith(
                                          color: Theme.of(context).accentColor),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            Row(
                              children: [
                                Icon(
                                  JamIcons.google_play,
                                  color: Theme.of(context).accentColor,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  "${wallpaper.data["icon"]}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .copyWith(
                                          color: Theme.of(context).accentColor),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            Row(
                              children: [
                                Icon(
                                  JamIcons.google_play,
                                  color: Theme.of(context).accentColor,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  "${wallpaper.data["widget"]}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .copyWith(
                                          color: Theme.of(context).accentColor),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            ActionChip(
                              backgroundColor: Colors.amber,
                              avatar: Icon(
                                JamIcons.clock,
                                color: Colors.black,
                              ),
                              onPressed: () {},
                              label: Text(
                                "IN REVIEW",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText2
                                    .copyWith(color: Colors.black),
                              ),
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(JamIcons.download,
                                        color: Theme.of(context).primaryColor),
                                    onPressed: () async {
                                      final status =
                                          await Permission.storage.status;
                                      if (!status.isGranted) {
                                        await Permission.storage.request();
                                      }
                                      final link =
                                          wallpaper.data["image"].toString();
                                      debugPrint(link);

                                      final androidInfo =
                                          await DeviceInfoPlugin().androidInfo;
                                      final sdkInt = androidInfo.version.sdkInt;
                                      debugPrint('(SDK $sdkInt)');
                                      toasts.codeSend("Starting Download");

                                      if (sdkInt >= 30) {
                                        await platform.invokeMethod(
                                            'save_setup',
                                            {"link": link}).then((value) {
                                          if (value as bool) {
                                            analytics.logEvent(
                                                name: 'download_own_setup',
                                                parameters: {'link': link});
                                            toasts.codeSend(
                                                "Setup Downloaded in Pictures/Prism Setup!");
                                          } else {
                                            toasts.error(
                                                "Couldn't download! Please Retry!");
                                          }
                                        }).catchError((e) {
                                          debugPrint(e.toString());
                                        });
                                      } else {
                                        GallerySaver.saveImage(link,
                                                albumName: "Prism Setups")
                                            .then((value) {
                                          analytics.logEvent(
                                              name: 'download_own_setup',
                                              parameters: {'link': link});
                                          toasts.codeSend(
                                              "Setup Downloaded in Internal Storage/Prism Setup!");
                                        }).catchError((e) {});
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 16,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(JamIcons.trash,
                                        color: Colors.white),
                                    onPressed: () async {
                                      final AlertDialog deleteWallPopUp =
                                          AlertDialog(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        title: Text(
                                          'Delete this setup?',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              color: Theme.of(context)
                                                  .accentColor),
                                        ),
                                        content: Text(
                                          "This is permanent, and this action can't be undone!",
                                          style: TextStyle(
                                              fontFamily: "Proxima Nova",
                                              fontWeight: FontWeight.normal,
                                              fontSize: 14,
                                              color: Theme.of(context)
                                                  .accentColor),
                                        ),
                                        actions: [
                                          FlatButton(
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5)),
                                            color: Theme.of(context).hintColor,
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              await firestore
                                                  .collection("setups")
                                                  .document(
                                                      wallpaper.documentID)
                                                  .delete();
                                              toasts.codeSend(
                                                  "Setup successfully deleted from server!");
                                            },
                                            child: const Text(
                                              'DELETE',
                                              style: TextStyle(
                                                fontSize: 16.0,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          FlatButton(
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5)),
                                            color: config.Colors()
                                                .mainAccentColor(1),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text(
                                              'CANCEL',
                                              style: TextStyle(
                                                fontSize: 16.0,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                        backgroundColor:
                                            Theme.of(context).primaryColor,
                                        actionsPadding:
                                            const EdgeInsets.fromLTRB(
                                                10, 0, 10, 0),
                                      );

                                      showModal(
                                          context: context,
                                          configuration:
                                              const FadeScaleTransitionConfiguration(),
                                          builder: (BuildContext context) =>
                                              deleteWallPopUp);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RejectedSetupTile extends StatelessWidget {
  final DocumentSnapshot wallpaper;
  RejectedSetupTile(this.wallpaper);
  final DateFormat formatter = DateFormat('d MMMM y, h:m a');
  static const platform = MethodChannel('flutter.prism.set_wallpaper');
  Firestore firestore = Firestore.instance;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 400,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        color: Theme.of(context).primaryColor,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: Theme.of(context).accentColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        JamIcons.clock,
                        color: Theme.of(context).accentColor,
                      ),
                      SizedBox(
                        width: 8,
                      ),
                      Text(
                        "${formatter.format((wallpaper.data["created_at"] as Timestamp).toDate().toLocal())}",
                        style: Theme.of(context)
                            .textTheme
                            .bodyText2
                            .copyWith(color: Theme.of(context).accentColor),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                CupertinoPageRoute(
                                    builder: (context) => PhotoView(
                                          onTapUp:
                                              (context, details, controller) {
                                            Navigator.pop(context);
                                          },
                                          imageProvider:
                                              CachedNetworkImageProvider(
                                            wallpaper.data["image"] as String,
                                          ),
                                        ),
                                    fullscreenDialog: true));
                          },
                          child: SizedBox(
                            height: 240,
                            width: 120,
                            child: CachedNetworkImage(
                              imageUrl: wallpaper.data["image"] as String,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 32,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  JamIcons.id_card,
                                  color: Theme.of(context).accentColor,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  "${wallpaper.data["id"]}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .copyWith(
                                          color: Theme.of(context).accentColor),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            Row(
                              children: [
                                Icon(
                                  JamIcons.google_play,
                                  color: Theme.of(context).accentColor,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  "${wallpaper.data["icon"]}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .copyWith(
                                          color: Theme.of(context).accentColor),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            Row(
                              children: [
                                Icon(
                                  JamIcons.google_play,
                                  color: Theme.of(context).accentColor,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  "${wallpaper.data["widget"]}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .copyWith(
                                          color: Theme.of(context).accentColor),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            ActionChip(
                              backgroundColor: Colors.red,
                              avatar: Icon(
                                JamIcons.close,
                                color: Colors.white,
                              ),
                              onPressed: () {},
                              label: Text(
                                "REJECTED",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText2
                                    .copyWith(color: Colors.white),
                              ),
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(JamIcons.download,
                                        color: Theme.of(context).primaryColor),
                                    onPressed: () async {
                                      final status =
                                          await Permission.storage.status;
                                      if (!status.isGranted) {
                                        await Permission.storage.request();
                                      }
                                      final link =
                                          wallpaper.data["image"].toString();
                                      debugPrint(link);

                                      final androidInfo =
                                          await DeviceInfoPlugin().androidInfo;
                                      final sdkInt = androidInfo.version.sdkInt;
                                      debugPrint('(SDK $sdkInt)');
                                      toasts.codeSend("Starting Download");

                                      if (sdkInt >= 30) {
                                        await platform.invokeMethod(
                                            'save_setup',
                                            {"link": link}).then((value) {
                                          if (value as bool) {
                                            analytics.logEvent(
                                                name: 'download_own_setup',
                                                parameters: {'link': link});
                                            toasts.codeSend(
                                                "Setup Downloaded in Pictures/Prism Setups!");
                                          } else {
                                            toasts.error(
                                                "Couldn't download! Please Retry!");
                                          }
                                        }).catchError((e) {
                                          debugPrint(e.toString());
                                        });
                                      } else {
                                        GallerySaver.saveImage(link,
                                                albumName: "Prism Setups")
                                            .then((value) {
                                          analytics.logEvent(
                                              name: 'download_own_setup',
                                              parameters: {'link': link});
                                          toasts.codeSend(
                                              "Setup Downloaded in Internal Storage/Prism Setups!");
                                        }).catchError((e) {});
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 16,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(JamIcons.trash,
                                        color: Colors.white),
                                    onPressed: () async {
                                      final AlertDialog deleteWallPopUp =
                                          AlertDialog(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        title: Text(
                                          'Delete this setup?',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              color: Theme.of(context)
                                                  .accentColor),
                                        ),
                                        content: Text(
                                          "This is permanent, and this action can't be undone!",
                                          style: TextStyle(
                                              fontFamily: "Proxima Nova",
                                              fontWeight: FontWeight.normal,
                                              fontSize: 14,
                                              color: Theme.of(context)
                                                  .accentColor),
                                        ),
                                        actions: [
                                          FlatButton(
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5)),
                                            color: Theme.of(context).hintColor,
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              await firestore
                                                  .collection("rejectedSetups")
                                                  .document(
                                                      wallpaper.documentID)
                                                  .delete();
                                              toasts.codeSend(
                                                  "Setup successfully deleted from server!");
                                            },
                                            child: const Text(
                                              'DELETE',
                                              style: TextStyle(
                                                fontSize: 16.0,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          FlatButton(
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5)),
                                            color: config.Colors()
                                                .mainAccentColor(1),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text(
                                              'CANCEL',
                                              style: TextStyle(
                                                fontSize: 16.0,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                        backgroundColor:
                                            Theme.of(context).primaryColor,
                                        actionsPadding:
                                            const EdgeInsets.fromLTRB(
                                                10, 0, 10, 0),
                                      );

                                      showModal(
                                          context: context,
                                          configuration:
                                              const FadeScaleTransitionConfiguration(),
                                          builder: (BuildContext context) =>
                                              deleteWallPopUp);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        JamIcons.close,
                        color: Theme.of(context).accentColor,
                      ),
                      SizedBox(
                        width: 8,
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.7,
                        child: Text(
                          "The setup didn't meet our expectations. Please try uploading another setup.",
                          style: Theme.of(context)
                              .textTheme
                              .bodyText2
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
