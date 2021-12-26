import 'dart:async';

import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/ui/widgets/home/core/inheritedScrollControllerProvider.dart';
import 'package:Prism/ui/widgets/menuButton/favIconButton.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:Prism/ui/widgets/premiumBanners/followingFeed.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:timeago/timeago.dart' as timeago;

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({
    Key? key,
  }) : super(key: key);

  @override
  _FollowingScreenState createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  StreamController<QuerySnapshot>? _streamController;
  late QuerySnapshot finalQuery;
  List<DocumentSnapshot> finalDocs = [];
  late List following;
  final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
  CollectionReference? walls;
  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    logger.d(navStack.toString());
    logger.d("Bye! Have a good day!");
    return true;
  }

  @override
  void initState() {
    super.initState();
    _streamController = StreamController.broadcast();
    _streamController!.stream.listen((p) {
      setState(() {
        finalQuery = p;
        finalDocs = [];
        for (final doc in finalQuery.docs) {
          if (following.contains(doc.data()["email"]) &&
              finalDocs.length <= 30) {
            finalDocs.add(doc);
          }
        }
      });
    });
    load(_streamController!);
  }

  Future<void> load(StreamController<QuerySnapshot> sc) async {
    await databaseReference
        .collection(USER_NEW_COLLECTION)
        .where("email", isEqualTo: globals.prismUser.email)
        .get()
        .then((value) {
      following = value.docs[0].data()["following"] as List? ?? [];
    });
    databaseReference
        .collection("walls")
        .where("review", isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(200)
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
        InheritedDataProvider.of(context)!.scrollController!;
    return WillPopScope(
      onWillPop: onWillPop,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
        child: StaggeredGridView.builder(
          gridDelegate: SliverStaggeredGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            staggeredTileCount: finalDocs != null ? finalDocs.length + 1 : 0,
            staggeredTileBuilder: (index) {
              return StaggeredTile.fit(index == finalDocs.length ? 2 : 1);
            },
          ),
          controller: controller,
          itemBuilder: (context, index) {
            if (index == finalDocs.length) {
              return Container(
                width: MediaQuery.of(context).size.width * 0.7,
                height: finalDocs.isEmpty
                    ? MediaQuery.of(context).size.height * 0.8
                    : 100,
                padding: EdgeInsets.symmetric(
                    horizontal: finalDocs.isEmpty ? 0 : 20),
                child: Center(
                  child: Text(
                    finalDocs.isEmpty
                        ? "Follow creators to see their latest posts here!"
                        : "You have caught up with the latest posts of the people you follow. Follow more people to see their posts.",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return FollowingTile(index, finalDocs);
          },
        ),
      ),
    );
  }
}

class FollowingTile extends StatefulWidget {
  final int index;
  final List<DocumentSnapshot> finalDocs;
  const FollowingTile(this.index, this.finalDocs);
  @override
  _FollowingTileState createState() => _FollowingTileState();
}

class _FollowingTileState extends State<FollowingTile> {
  final now = DateTime.now().toUtc();
  double? height;

  @override
  void initState() {
    height = 0;
    super.initState();
  }

  void showGooglePopUp(BuildContext context, Function func) {
    logger.d(globals.prismUser.loggedIn.toString());
    if (globals.prismUser.loggedIn == false) {
      googleSignInPopUp(context, func);
    } else {
      func();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.index >= widget.finalDocs.length) {
      return Container();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        children: [
          PremiumBannerFollowingFeed(
            comparator: !globals.isPremiumWall(globals.premiumCollections,
                widget.finalDocs[widget.index]["collections"] as List? ?? []),
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    globals.isPremiumWall(
                                    globals.premiumCollections,
                                    widget.finalDocs[widget.index]
                                            ["collections"] as List? ??
                                        []) ==
                                true &&
                            globals.prismUser.premium != true
                        ? showGooglePopUp(context, () {
                            Navigator.pushNamed(
                              context,
                              premiumRoute,
                            );
                          })
                        : Navigator.pushNamed(context, shareRoute, arguments: [
                            widget.finalDocs[widget.index]["id"],
                            widget.finalDocs[widget.index]
                                ["wallpaper_provider"],
                            widget.finalDocs[widget.index]["wallpaper_url"],
                            widget.finalDocs[widget.index]["wallpaper_thumb"]
                          ]);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: CachedNetworkImage(
                      imageUrl: widget.finalDocs[widget.index]
                          ["wallpaper_thumb"] as String,
                      placeholder: (context, url) {
                        return Container(
                          height: 400,
                          color: Theme.of(context).hintColor,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, followerProfileRoute,
                        arguments: [
                          widget.finalDocs[widget.index]["email"],
                        ]);
                  },
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
                            child: CircleAvatar(
                              backgroundImage: CachedNetworkImageProvider(
                                  widget.finalDocs[widget.index]["userPhoto"]
                                      as String),
                              radius: 16,
                            ),
                          ),
                          if (globals.verifiedUsers.contains(widget
                              .finalDocs[widget.index]["email"]
                              .toString()))
                            Container(
                              width: 15,
                              height: 15,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: SvgPicture.string(verifiedIcon.replaceAll(
                                  "E57697",
                                  Theme.of(context).errorColor == Colors.black
                                      ? "E57697"
                                      : Theme.of(context)
                                          .errorColor
                                          .toString()
                                          .replaceAll("Color(0xff", "")
                                          .replaceAll(")", ""))),
                            )
                          else
                            Container(),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.2,
                            child: Text(
                              widget.finalDocs[widget.index]["by"].toString(),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyText2!
                                  .copyWith(
                                      color: Theme.of(context).accentColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.2,
                            child: Text(
                              timeago.format(
                                now.subtract(
                                  now.difference(
                                    (widget.finalDocs[widget.index]["createdAt"]
                                            as Timestamp)
                                        .toDate(),
                                  ),
                                ),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyText2!
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
                const Spacer(),
                if (globals.isPremiumWall(
                            globals.premiumCollections,
                            widget.finalDocs[widget.index]["collections"]
                                    as List? ??
                                []) ==
                        true &&
                    globals.prismUser.premium != true)
                  Container()
                else
                  FavIconButton(
                    id: widget.finalDocs[widget.index]["id"] as String?,
                    prism: widget.finalDocs[widget.index].data(),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
