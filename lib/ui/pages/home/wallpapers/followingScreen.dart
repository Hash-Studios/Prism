import 'dart:async';

import 'package:Prism/main.dart' as main;
import 'package:Prism/routes/router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:Prism/ui/widgets/home/core/inheritedScrollControllerProvider.dart';
import 'package:Prism/ui/widgets/menuButton/favIconButton.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/ui/widgets/home/collections/collectionsGrid.dart';

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({
    Key key,
  }) : super(key: key);

  @override
  _FollowingScreenState createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  StreamController<QuerySnapshot> _streamController;
  QuerySnapshot finalQuery;
  List<DocumentSnapshot> finalDocs = [];
  List following;
  final Firestore databaseReference = Firestore.instance;
  CollectionReference walls;
  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    debugPrint("Bye! Have a good day!");
    return true;
  }

  @override
  void initState() {
    super.initState();
    _streamController = StreamController.broadcast();
    _streamController.stream.listen((p) {
      setState(() {
        finalQuery = p;
        finalDocs = [];
        for (final doc in finalQuery.documents) {
          if (following.contains(doc.data["email"]) && finalDocs.length <= 50) {
            finalDocs.add(doc);
          }
        }
      });
    });
    load(_streamController);
  }

  load(StreamController<QuerySnapshot> sc) async {
    await databaseReference
        .collection("users")
        .where("email", isEqualTo: main.prefs.get('email'))
        .getDocuments()
        .then((value) {
      following = value.documents[0].data["following"] as List ?? [];
    });
    databaseReference
        .collection("walls")
        .where("review", isEqualTo: true)
        .orderBy('createdAt', descending: true)
        // .limit(200)
        .snapshots()
        .pipe(sc);
  }

  @override
  void dispose() {
    super.dispose();
    _streamController?.close();
    _streamController = null;
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController controller =
        InheritedDataProvider.of(context).scrollController;
    return WillPopScope(
      onWillPop: onWillPop,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
        child: StaggeredGridView.builder(
          gridDelegate: SliverStaggeredGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            staggeredTileCount: finalDocs != null ? finalDocs.length : 0,
            staggeredTileBuilder: (index) {
              return StaggeredTile.fit(1);
            },
          ),
          controller: controller,
          itemBuilder: (context, index) {
            return _makeElement(index);
          },
        ),
      ),
    );
  }

  void showGooglePopUp(BuildContext context, Function func) {
    debugPrint(main.prefs.get("isLoggedin").toString());
    if (main.prefs.get("isLoggedin") == false) {
      googleSignInPopUp(context, func);
    } else {
      func();
    }
  }

  Widget _makeElement(int index) {
    final now = DateTime.now();
    if (index >= finalDocs.length) {
      return null;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        children: [
          GestureDetector(
              onTap: () {
                globals.isPremiumWall(
                                globals.premiumCollections,
                                finalDocs[index]["collections"] as List ??
                                    []) ==
                            true &&
                        main.prefs.get('premium') != true
                    ? showGooglePopUp(context, () {
                        Navigator.pushNamed(
                          context,
                          premiumRoute,
                        );
                      })
                    : Navigator.pushNamed(context, shareRoute, arguments: [
                        finalDocs[index]["id"],
                        finalDocs[index]["wallpaper_provider"],
                        finalDocs[index]["wallpaper_url"],
                        finalDocs[index]["wallpaper_thumb"]
                      ]);
              },
              child: PremiumBannerFollowingFeed(
                comparator: !globals.isPremiumWall(globals.premiumCollections,
                    finalDocs[index]["collections"] as List ?? []),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: CachedNetworkImage(
                    imageUrl: finalDocs[index]["wallpaper_thumb"] as String,
                  ),
                ),
              )),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, photographerProfileRoute,
                        arguments: [
                          finalDocs[index]["by"],
                          finalDocs[index]["email"],
                          finalDocs[index]["userPhoto"],
                          false,
                          finalDocs[index]["twitter"] != null &&
                                  finalDocs[index]["twitter"] != ""
                              ? finalDocs[index]["twitter"]
                                  .toString()
                                  .split("https://www.twitter.com/")[1]
                              : "",
                          finalDocs[index]["instagram"] != null &&
                                  finalDocs[index]["instagram"] != ""
                              ? finalDocs[index]["instagram"]
                                  .toString()
                                  .split("https://www.instagram.com/")[1]
                              : "",
                        ]);
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(
                            finalDocs[index]["userPhoto"] as String),
                        radius: 16,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              finalDocs[index]["by"].toString(),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyText2
                                  .copyWith(
                                      color: Theme.of(context).accentColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: Text(
                              timeago.format(
                                now.subtract(
                                  now.difference(
                                    (finalDocs[index]["createdAt"] as Timestamp)
                                        .toDate(),
                                  ),
                                ),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyText2
                                  .copyWith(
                                      color: Theme.of(context)
                                          .accentColor
                                          .withOpacity(0.8),
                                      fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Spacer(),
                FavIconButton(
                  id: finalDocs[index]["id"] as String,
                  prism: finalDocs[index].data,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
