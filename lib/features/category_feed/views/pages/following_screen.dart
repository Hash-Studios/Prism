import 'dart:async';

import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/router/route_names.dart';
import 'package:Prism/core/widgets/menuButton/favIconButton.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/core/widgets/premiumBanners/followingFeed.dart';
import 'package:Prism/features/navigation/views/widgets/inherited_scroll_controller_provider.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:timeago/timeago.dart' as timeago;

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({
    super.key,
  });

  @override
  _FollowingScreenState createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  StreamController<QuerySnapshot<Map<String, dynamic>>>? _streamController;
  late QuerySnapshot<Map<String, dynamic>> finalQuery;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> finalDocs = [];
  late List following;
  final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
  CollectionReference? walls;
  Future<bool> onWillPop() async {
    popNavStackIfPossible();
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
          if (following.contains(doc.data()["email"]) && finalDocs.length <= 30) {
            finalDocs.add(doc);
          }
        }
      });
    });
    load(_streamController!);
  }

  Future<void> load(StreamController<QuerySnapshot<Map<String, dynamic>>> sc) async {
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
    final ScrollController controller = InheritedDataProvider.of(context)!.scrollController!;
    return WillPopScope(
      onWillPop: onWillPop,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
        child: MasonryGridView.builder(
          gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          itemCount: finalDocs.length + 1,
          controller: controller,
          itemBuilder: (context, index) {
            if (index == finalDocs.length) {
              return Container(
                width: MediaQuery.of(context).size.width * 0.7,
                height: finalDocs.isEmpty ? MediaQuery.of(context).size.height * 0.8 : 100,
                padding: EdgeInsets.symmetric(horizontal: finalDocs.isEmpty ? 0 : 20),
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
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> finalDocs;
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
            comparator: !globals.isPremiumWall(
                globals.premiumCollections, widget.finalDocs[widget.index]["collections"] as List? ?? []),
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    globals.isPremiumWall(globals.premiumCollections,
                                    widget.finalDocs[widget.index]["collections"] as List? ?? []) ==
                                true &&
                            globals.prismUser.premium != true
                        ? showGooglePopUp(context, () {
                            context.pushNamedRoute(
                              premiumRoute,
                            );
                          })
                        : context.pushNamedRoute(shareRoute, arguments: [
                            widget.finalDocs[widget.index]["id"],
                            widget.finalDocs[widget.index]["wallpaper_provider"],
                            widget.finalDocs[widget.index]["wallpaper_url"],
                            widget.finalDocs[widget.index]["wallpaper_thumb"]
                          ]);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: CachedNetworkImage(
                      imageUrl: widget.finalDocs[widget.index]["wallpaper_thumb"] as String,
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
                    context.pushNamedRoute(followerProfileRoute, arguments: [
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
                              backgroundImage:
                                  CachedNetworkImageProvider(widget.finalDocs[widget.index]["userPhoto"] as String),
                              radius: 16,
                            ),
                          ),
                          if (globals.verifiedUsers.contains(widget.finalDocs[widget.index]["email"].toString()))
                            Container(
                              width: 15,
                              height: 15,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: SvgPicture.string(verifiedIcon.replaceAll(
                                  "E57697",
                                  Theme.of(context).colorScheme.error == Colors.black
                                      ? "E57697"
                                      : Theme.of(context)
                                          .colorScheme
                                          .error
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
                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  color: Theme.of(context).colorScheme.secondary,
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
                                    (widget.finalDocs[widget.index]["createdAt"] as Timestamp).toDate(),
                                  ),
                                ),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8), fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (globals.isPremiumWall(
                            globals.premiumCollections, widget.finalDocs[widget.index]["collections"] as List? ?? []) ==
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
