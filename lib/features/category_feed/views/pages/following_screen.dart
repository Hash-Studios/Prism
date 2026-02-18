import 'dart:async';

import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/menuButton/favIconButton.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/core/widgets/premiumBanners/followingFeed.dart';
import 'package:Prism/features/navigation/views/widgets/inherited_scroll_controller_provider.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rxdart/rxdart.dart';
import 'package:timeago/timeago.dart' as timeago;

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});

  @override
  _FollowingScreenState createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  static const int _followingChunkSize = 10;
  static const int _maxPerChunkLimit = 20;
  static const int _maxFeedItems = 30;

  StreamSubscription<List<_FirestoreDoc>>? _feedSubscription;
  List<_FirestoreDoc> finalDocs = <_FirestoreDoc>[];
  List<String> following = <String>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadFollowingFeed());
  }

  List<String> _normalizeEmails(List<dynamic> raw) {
    return raw
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Future<List<String>> _resolveFollowingEmails() async {
    final List<String> fromGlobal = _normalizeEmails(globals.prismUser.following);
    if (fromGlobal.isNotEmpty) {
      return fromGlobal;
    }
    if (globals.prismUser.email.trim().isEmpty) {
      return <String>[];
    }
    final currentUserDocs = await firestoreClient.query<Map<String, dynamic>>(
      FirestoreQuerySpec(
        collection: USER_NEW_COLLECTION,
        sourceTag: 'following.currentUser',
        filters: <FirestoreFilter>[
          FirestoreFilter(field: "email", op: FirestoreFilterOp.isEqualTo, value: globals.prismUser.email.trim()),
        ],
        limit: 1,
        cachePolicy: FirestoreCachePolicy.memoryFirst,
        dedupeWindowMs: 30000,
      ),
      (data, _) => data,
    );
    if (currentUserDocs.isEmpty) {
      return <String>[];
    }
    final List<String> remote = _normalizeEmails(currentUserDocs.first["following"] as List? ?? <dynamic>[]);
    globals.prismUser.following = remote;
    return remote;
  }

  List<List<String>> _chunks(List<String> input, int chunkSize) {
    final List<List<String>> output = <List<String>>[];
    for (int i = 0; i < input.length; i += chunkSize) {
      final int end = (i + chunkSize < input.length) ? i + chunkSize : input.length;
      output.add(input.sublist(i, end));
    }
    return output;
  }

  List<_FirestoreDoc> _dedupeSortAndLimit(List<_FirestoreDoc> docs) {
    final Map<String, _FirestoreDoc> unique = <String, _FirestoreDoc>{};
    for (final _FirestoreDoc doc in docs) {
      final dynamic rawId = doc['id'];
      final String key = rawId?.toString().trim().isNotEmpty == true ? rawId.toString() : doc.id;
      unique[key] = doc;
    }
    final List<_FirestoreDoc> result = unique.values.toList(growable: false)
      ..sort((a, b) => _toDateTime(b["createdAt"]).compareTo(_toDateTime(a["createdAt"])));
    if (result.length <= _maxFeedItems) {
      return result;
    }
    return result.sublist(0, _maxFeedItems);
  }

  int _resolvePerChunkLimit(int chunkCount) {
    if (chunkCount <= 0) {
      return _maxPerChunkLimit;
    }
    final int computed = (_maxFeedItems / chunkCount).ceil();
    return computed.clamp(8, _maxPerChunkLimit);
  }

  Future<void> _loadFollowingFeed() async {
    await _feedSubscription?.cancel();
    final List<String> currentFollowing = await _resolveFollowingEmails();
    if (!mounted) {
      return;
    }
    setState(() {
      following = currentFollowing;
      finalDocs = <_FirestoreDoc>[];
    });
    if (currentFollowing.isEmpty) {
      return;
    }

    final List<List<String>> chunked = _chunks(currentFollowing, _followingChunkSize);
    final int perChunkLimit = _resolvePerChunkLimit(chunked.length);
    final List<Stream<List<_FirestoreDoc>>> streams = chunked
        .asMap()
        .entries
        .map((entry) {
          final int index = entry.key;
          final List<String> chunk = entry.value;
          return firestoreClient.watchQuery<_FirestoreDoc>(
            FirestoreQuerySpec(
              collection: FirebaseCollections.walls,
              sourceTag: 'following.feed.chunk_${index + 1}',
              filters: <FirestoreFilter>[
                const FirestoreFilter(field: "review", op: FirestoreFilterOp.isEqualTo, value: true),
                FirestoreFilter(field: "email", op: FirestoreFilterOp.whereIn, value: chunk),
              ],
              orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
              limit: perChunkLimit,
              isStream: true,
            ),
            (data, docId) => _FirestoreDoc(docId, data),
          );
        })
        .toList(growable: false);

    final Stream<List<_FirestoreDoc>> merged = streams.length == 1
        ? streams.first
        : Rx.combineLatestList<List<_FirestoreDoc>>(
            streams,
          ).map((batches) => batches.expand((docs) => docs).toList(growable: false));

    _feedSubscription = merged.listen(
      (docs) {
        if (!mounted) {
          return;
        }
        setState(() {
          finalDocs = _dedupeSortAndLimit(docs);
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        logger.e('Following feed stream failed', error: error, stackTrace: stackTrace);
      },
    );
  }

  @override
  void dispose() {
    _feedSubscription?.cancel();
    _feedSubscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController controller = InheritedDataProvider.of(context)!.scrollController!;
    return Padding(
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

  void showGooglePopUp(BuildContext context, VoidCallback func) {
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
              globals.premiumCollections,
              widget.finalDocs[widget.index]["collections"] as List? ?? [],
            ),
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    globals.isPremiumWall(
                                  globals.premiumCollections,
                                  widget.finalDocs[widget.index]["collections"] as List? ?? [],
                                ) ==
                                true &&
                            globals.prismUser.premium != true
                        ? showGooglePopUp(context, () {
                            context.router.push(const UpgradeRoute());
                          })
                        : context.router.push(
                            ShareWallpaperViewRoute(
                              arguments: [
                                widget.finalDocs[widget.index]["id"],
                                widget.finalDocs[widget.index]["wallpaper_provider"],
                                widget.finalDocs[widget.index]["wallpaper_url"],
                                widget.finalDocs[widget.index]["wallpaper_thumb"],
                              ],
                            ),
                          );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: CachedNetworkImage(
                      imageUrl: widget.finalDocs[widget.index]["wallpaper_thumb"] as String,
                      placeholder: (context, url) {
                        return Container(height: 400, color: Theme.of(context).hintColor);
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
                    context.router.push(ProfileRoute(arguments: [widget.finalDocs[widget.index]["email"]]));
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
                                widget.finalDocs[widget.index]["userPhoto"] as String,
                              ),
                              radius: 16,
                            ),
                          ),
                          if (globals.verifiedUsers.contains(widget.finalDocs[widget.index]["email"].toString()))
                            Container(
                              width: 15,
                              height: 15,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                              child: SvgPicture.string(
                                verifiedIcon.replaceAll(
                                  "E57697",
                                  Theme.of(context).colorScheme.error == Colors.black
                                      ? "E57697"
                                      : Theme.of(
                                          context,
                                        ).colorScheme.error.toString().replaceAll("Color(0xff", "").replaceAll(")", ""),
                                ),
                              ),
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
                                fontSize: 12,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.2,
                            child: Text(
                              timeago.format(
                                now.subtract(now.difference(_toDateTime(widget.finalDocs[widget.index]["createdAt"]))),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                                fontSize: 10,
                              ),
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
                          widget.finalDocs[widget.index]["collections"] as List? ?? [],
                        ) ==
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
          ),
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
    return value.toUtc();
  }
  if (value is Timestamp) {
    return value.toDate().toUtc();
  }
  if (value is String) {
    try {
      return DateTime.parse(value).toUtc();
    } catch (_) {
      return DateTime.now().toUtc();
    }
  }
  return DateTime.now().toUtc();
}
