import 'dart:async';

import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/router/route_names.dart';
import 'package:Prism/core/widgets/menuButton/favIconButton.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/core/widgets/premiumBanners/followingFeed.dart';
import 'package:Prism/features/navigation/views/widgets/inherited_scroll_controller_provider.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  StreamController<List<_FirestoreDoc>>? _streamController;
  List<_FirestoreDoc> finalDocs = <_FirestoreDoc>[];
  List<dynamic> following = <dynamic>[];
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
        finalDocs = [];
        for (final doc in p) {
          if (following.contains(doc.data()["email"]) && finalDocs.length <= 30) {
            finalDocs.add(doc);
          }
        }
      });
    });
    load(_streamController!);
  }

  Future<void> load(StreamController<List<_FirestoreDoc>> sc) async {
    final currentUserDocs = await firestoreClient.query<Map<String, dynamic>>(
      FirestoreQuerySpec(
        collection: USER_NEW_COLLECTION,
        sourceTag: 'following.currentUser',
        filters: <FirestoreFilter>[
          FirestoreFilter(field: "email", op: FirestoreFilterOp.isEqualTo, value: globals.prismUser.email),
        ],
        limit: 1,
      ),
      (data, _) => data,
    );
    following = currentUserDocs.isNotEmpty ? (currentUserDocs.first["following"] as List? ?? <dynamic>[]) : <dynamic>[];

    firestoreClient
        .watchQuery<_FirestoreDoc>(
          const FirestoreQuerySpec(
            collection: FirebaseCollections.walls,
            sourceTag: 'following.feed',
            filters: <FirestoreFilter>[
              FirestoreFilter(field: "review", op: FirestoreFilterOp.isEqualTo, value: true),
            ],
            orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
            limit: 200,
            isStream: true,
          ),
          (data, docId) => _FirestoreDoc(docId, data),
        )
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
  final List<_FirestoreDoc> finalDocs;
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
                                    _toDateTime(widget.finalDocs[widget.index]["createdAt"]),
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

class _FirestoreDoc {
  const _FirestoreDoc(this.id, this.payload);

  final String id;
  final Map<String, dynamic> payload;

  Map<String, dynamic> data() => payload;
  dynamic operator [](String key) => payload[key];
}

DateTime _toDateTime(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  final dynamic withToDate = value;
  if (withToDate != null && withToDate.toDate is Function) {
    return withToDate.toDate() as DateTime;
  }
  return DateTime.now().toUtc();
}
