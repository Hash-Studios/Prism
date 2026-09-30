import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/wallpaper/setup_wallpaper_value.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/features/setups/views/widgets/rejection_feedback.dart';
import 'package:Prism/features/setups/views/widgets/review_tile_parts.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';

@RoutePage()
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: AppBar(
            title: Row(
              children: [
                Text("Review Status", style: Theme.of(context).textTheme.displaySmall),
                Container(
                  margin: const EdgeInsets.only(left: 3, bottom: 5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(500),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 4),
                    child: Text("BETA", style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.secondary)),
                  ),
                ),
              ],
            ),
            leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(JamIcons.chevron_left),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            backgroundColor: Theme.of(context).primaryColor,
          ),
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.secondary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(
                child: Text(
                  "Wallpapers",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                ),
              ),
              Tab(
                child: Text(
                  "Setups",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        body: const TabBarView(children: [_WallReview(), _SetupReview()]),
      ),
    );
  }
}

class _WallReview extends StatelessWidget {
  const _WallReview();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          StreamBuilder<List<FirestoreDocument>>(
            stream: firestoreClient.watchQuery<FirestoreDocument>(
              FirestoreQuerySpec(
                collection: FirebaseCollections.rejectedWalls,
                sourceTag: 'review.rejectedWalls',
                filters: <FirestoreFilter>[
                  FirestoreFilter(field: "email", op: FirestoreFilterOp.isEqualTo, value: app_state.prismUser.email),
                ],
                orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
                isStream: true,
              ),
              (data, docId) => FirestoreDocument(docId, data),
            ),
            builder: (BuildContext context, AsyncSnapshot<List<FirestoreDocument>> snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              } else {
                return Column(
                  children: List.generate(
                    snapshot.data!.length,
                    (int index) => WallTile(snapshot.data![index], rejected: true),
                  ),
                );
              }
            },
          ),
          StreamBuilder<List<FirestoreDocument>>(
            stream: firestoreClient.watchQuery<FirestoreDocument>(
              FirestoreQuerySpec(
                collection: FirebaseCollections.walls,
                sourceTag: 'review.pendingWalls',
                filters: <FirestoreFilter>[
                  FirestoreFilter(field: "email", op: FirestoreFilterOp.isEqualTo, value: app_state.prismUser.email),
                  const FirestoreFilter(field: "review", op: FirestoreFilterOp.isEqualTo, value: false),
                ],
                orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
                isStream: true,
              ),
              (data, docId) => FirestoreDocument(docId, data),
            ),
            builder: (BuildContext context, AsyncSnapshot<List<FirestoreDocument>> snapshot) {
              if (snapshot.hasError) return const _ReviewMessage("Couldn't load your submissions.");
              if (!snapshot.hasData) {
                return Center(child: Loader());
              } else if (snapshot.data!.isEmpty) {
                return const _ReviewMessage('No wallpapers waiting for review.');
              } else {
                return Column(
                  children: List.generate(
                    snapshot.data!.length,
                    (int index) => WallTile(snapshot.data![index], rejected: false),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ReviewMessage extends StatelessWidget {
  const _ReviewMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class WallTile extends StatelessWidget {
  const WallTile(this.wallpaper, {required this.rejected});

  final FirestoreDocument wallpaper;
  final bool rejected;

  @override
  Widget build(BuildContext context) {
    final DateTime? createdAt = wallpaper.createdAt;
    return Container(
      width: MediaQuery.of(context).size.width,
      constraints: rejected ? null : const BoxConstraints(minHeight: 340),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        color: Theme.of(context).primaryColor,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (createdAt != null) ReviewInfoRow(icon: JamIcons.clock, text: _formatCreatedAt(createdAt)),
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
                                  onTapUp: (context, details, controller) {
                                    Navigator.pop(context);
                                  },
                                  imageProvider: CachedNetworkImageProvider(wallpaper.wallpaperUrl),
                                ),
                                fullscreenDialog: true,
                              ),
                            );
                          },
                          child: SizedBox(
                            height: 240,
                            width: 120,
                            child: CachedNetworkImage(imageUrl: wallpaper.wallpaperThumb, fit: BoxFit.contain),
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ReviewInfoRow(icon: JamIcons.id_card, text: wallpaper.id),
                              const SizedBox(height: 16),
                              ReviewInfoRow(icon: JamIcons.save, text: wallpaper.size),
                              const SizedBox(height: 16),
                              ReviewInfoRow(icon: JamIcons.set_square, text: wallpaper.resolution),
                              const SizedBox(height: 16),
                              _ReviewStatusChip(rejected: rejected),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  ReviewDownloadButton(
                                    link: wallpaper.wallpaperUrl,
                                    kind: SaveMediaKind.wallpaper,
                                    event: DownloadOwnWallEvent(link: wallpaper.wallpaperUrl),
                                    successMessage: "Wall Downloaded in Pictures/Prism!",
                                    failLogSuffix: rejected ? 'rejected wall download' : 'review wall download',
                                    showNotification: true,
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: IconButton(
                                      icon: const Icon(JamIcons.trash, color: Colors.white),
                                      onPressed: () => showDeleteConfirm(
                                        context,
                                        title: 'Delete this wallpaper?',
                                        onConfirm: () => _reviewDeleteDoc(
                                          collection: rejected
                                              ? FirebaseCollections.rejectedWalls
                                              : FirebaseCollections.walls,
                                          id: wallpaper.id,
                                          sourceTag: rejected ? 'review.rejectedWall.delete' : 'review.wall.delete',
                                          successToast: "Wallpaper successfully deleted from server!",
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (rejected) RejectionFeedback(reason: wallpaper.data()['rejectionReason']?.toString()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewStatusChip extends StatelessWidget {
  const _ReviewStatusChip({required this.rejected});

  final bool rejected;

  @override
  Widget build(BuildContext context) {
    final Color foreground = rejected ? Colors.white : Colors.black;
    return ActionChip(
      backgroundColor: rejected ? Colors.red : Colors.amber,
      avatar: Icon(rejected ? JamIcons.close : JamIcons.clock, color: foreground),
      onPressed: () {},
      label: Text(
        rejected ? "REJECTED" : "IN REVIEW",
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: foreground),
      ),
    );
  }
}

class _SetupReview extends StatelessWidget {
  const _SetupReview();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          StreamBuilder<List<FirestoreDocument>>(
            stream: firestoreClient.watchQuery<FirestoreDocument>(
              FirestoreQuerySpec(
                collection: FirebaseCollections.rejectedSetups,
                sourceTag: 'review.rejectedSetups',
                filters: <FirestoreFilter>[
                  FirestoreFilter(field: "email", op: FirestoreFilterOp.isEqualTo, value: app_state.prismUser.email),
                ],
                orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'created_at', descending: true)],
                isStream: true,
              ),
              (data, docId) => FirestoreDocument(docId, data),
            ),
            builder: (BuildContext context, AsyncSnapshot<List<FirestoreDocument>> snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              } else {
                return Column(
                  children: List.generate(
                    snapshot.data!.length,
                    (int index) => SetupTile(snapshot.data![index], false, rejected: true),
                  ),
                );
              }
            },
          ),
          StreamBuilder<List<FirestoreDocument>>(
            stream: firestoreClient.watchQuery<FirestoreDocument>(
              FirestoreQuerySpec(
                collection: FirebaseCollections.setups,
                sourceTag: 'review.pendingSetups',
                filters: <FirestoreFilter>[
                  FirestoreFilter(field: "email", op: FirestoreFilterOp.isEqualTo, value: app_state.prismUser.email),
                  const FirestoreFilter(field: "review", op: FirestoreFilterOp.isEqualTo, value: false),
                ],
                orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'created_at', descending: true)],
                isStream: true,
              ),
              (data, docId) => FirestoreDocument(docId, data),
            ),
            builder: (BuildContext context, AsyncSnapshot<List<FirestoreDocument>> snapshot) {
              if (snapshot.hasError) return const _ReviewMessage("Couldn't load your submissions.");
              if (!snapshot.hasData) {
                return Center(child: Loader());
              } else if (snapshot.data!.isEmpty) {
                return const _ReviewMessage('No setups waiting for review.');
              } else {
                return Column(
                  children: List.generate(
                    snapshot.data!.length,
                    (int index) => SetupTile(snapshot.data![index], false),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class SetupTile extends StatelessWidget {
  const SetupTile(this.wallpaper, this.draft, {super.key, this.rejected = false});

  final FirestoreDocument wallpaper;
  final bool draft;
  final bool rejected;

  void _openLink(BuildContext context, String url) {
    openPrismLink(context, url).catchError((e) {
      toasts.error("Error in link!");
      return false;
    });
  }

  void _openWallpaper(BuildContext context, SetupWallpaperValue value) {
    if (!rejected && value.primaryUrl.isEmpty) {
      toasts.error("Wallpaper not added!");
      return;
    }
    if (!value.isEncoded && wallpaper.wallId.isNotEmpty) {
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => PhotoView(
            onTapUp: (context, details, controller) {
              Navigator.pop(context);
            },
            imageProvider: CachedNetworkImageProvider(value.primaryUrl),
          ),
          fullscreenDialog: true,
        ),
      );
    } else {
      _openLink(context, value.primaryUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SetupWallpaperValue wallpaperValue = SetupWallpaperValue.parse(wallpaper.wallpaperUrl);
    final bool hasSecondWidget = wallpaper.widget2.isNotEmpty;
    final DateTime? createdAt = wallpaper.createdAt;
    return Container(
      width: MediaQuery.of(context).size.width,
      constraints: rejected
          ? null
          : BoxConstraints(minHeight: hasSecondWidget ? 420 : 390, maxHeight: hasSecondWidget ? 470 : 440),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        color: Theme.of(context).primaryColor,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (createdAt != null) ReviewInfoRow(icon: JamIcons.clock, text: _formatCreatedAt(createdAt)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => PhotoView(
                                      onTapUp: (context, details, controller) {
                                        Navigator.pop(context);
                                      },
                                      imageProvider: CachedNetworkImageProvider(wallpaper.image),
                                    ),
                                    fullscreenDialog: true,
                                  ),
                                );
                              },
                              child: SizedBox(
                                height: 240,
                                width: 120,
                                child: CachedNetworkImage(imageUrl: wallpaper.image, fit: BoxFit.contain),
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                toasts.success("${wallpaper.name} - ${wallpaper.desc}");
                              },
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.3,
                                child: RichText(
                                  text: TextSpan(
                                    text: rejected
                                        ? wallpaper.name
                                        : (wallpaper.name.isEmpty ? "No name" : wallpaper.name),
                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: rejected
                                            ? " - ${wallpaper.desc}"
                                            : (wallpaper.desc.isEmpty ? " - No desc" : " - ${wallpaper.desc}"),
                                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                          decoration: TextDecoration.underline,
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ReviewInfoRow(icon: JamIcons.id_card, text: wallpaper.id, fixedWidth: true),
                              const SizedBox(height: 16),
                              ReviewInfoRow(
                                icon: JamIcons.picture,
                                text: rejected || wallpaperValue.primaryUrl.isNotEmpty
                                    ? wallpaperValue.tileText(wallId: wallpaper.wallId)
                                    : "Wallpaper",
                                underline: true,
                                fixedWidth: true,
                                onTap: () => _openWallpaper(context, wallpaperValue),
                              ),
                              const SizedBox(height: 16),
                              ReviewInfoRow(
                                icon: JamIcons.google_play,
                                text: rejected ? wallpaper.icon : (wallpaper.icon.isEmpty ? "No icon" : wallpaper.icon),
                                underline: true,
                                fixedWidth: true,
                                onTap: () {
                                  if (!rejected && wallpaper.iconUrl.isEmpty) {
                                    toasts.error("No icons added!");
                                    return;
                                  }
                                  _openLink(context, wallpaper.iconUrl);
                                },
                              ),
                              if (wallpaper.widget.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                ReviewInfoRow(
                                  icon: JamIcons.google_play,
                                  text: wallpaper.widget,
                                  underline: true,
                                  fixedWidth: true,
                                  onTap: () => _openLink(context, wallpaper.widgetUrl),
                                ),
                              ],
                              if (hasSecondWidget) ...[
                                const SizedBox(height: 16),
                                ReviewInfoRow(
                                  icon: JamIcons.google_play,
                                  text: wallpaper.widget2,
                                  underline: true,
                                  fixedWidth: true,
                                  onTap: () => _openLink(context, wallpaper.widgetUrl2),
                                ),
                              ],
                              const SizedBox(height: 16),
                              if (rejected || !draft) _ReviewStatusChip(rejected: rejected),
                              const SizedBox(height: 16),
                              if (rejected)
                                Row(
                                  children: [
                                    _downloadButton(
                                      "Setup Downloaded in Pictures/Prism Setups!",
                                      'rejected setup download',
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      child: IconButton(
                                        icon: const Icon(JamIcons.trash, color: Colors.white),
                                        onPressed: () => showDeleteConfirm(
                                          context,
                                          title: 'Delete this setup?',
                                          onConfirm: () => _reviewDeleteDoc(
                                            collection: FirebaseCollections.rejectedSetups,
                                            id: wallpaper.id,
                                            sourceTag: 'review.rejectedSetup.delete',
                                            successToast: "Setup successfully deleted from server!",
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                Wrap(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.secondary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: Icon(JamIcons.pencil, color: Theme.of(context).primaryColor),
                                        onPressed: () {
                                          context.router.push(EditSetupReviewRoute(setupDoc: wallpaper));
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _downloadButton(
                                      "Setup Downloaded in Pictures/Prism Setup!",
                                      'review setup download',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ActionChip(
                                  backgroundColor: Colors.red,
                                  avatar: const Icon(JamIcons.trash, color: Colors.white),
                                  label: Text(
                                    "DELETE",
                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.white),
                                  ),
                                  onPressed: () => showDeleteConfirm(
                                    context,
                                    title: draft ? 'Delete this draft?' : 'Delete this setup?',
                                    onConfirm: () => draft
                                        ? _reviewDeleteDoc(
                                            collection: FirebaseCollections.draftSetups,
                                            id: wallpaper.id,
                                            sourceTag: 'review.draftSetup.delete',
                                            successToast: "Draft successfully deleted from server!",
                                          )
                                        : _reviewDeleteDoc(
                                            collection: FirebaseCollections.setups,
                                            id: wallpaper.id,
                                            sourceTag: 'review.setup.delete',
                                            successToast: "Setup successfully deleted from server!",
                                          ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (rejected) RejectionFeedback(reason: wallpaper.data()['rejectionReason']?.toString()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _downloadButton(String successMessage, String failLogSuffix) => ReviewDownloadButton(
    link: wallpaper.image,
    kind: SaveMediaKind.setup,
    event: DownloadOwnSetupEvent(link: wallpaper.image),
    successMessage: successMessage,
    failLogSuffix: failLogSuffix,
  );
}

final DateFormat _createdAtFormat = DateFormat('d MMMM y, h:mm a');

String _formatCreatedAt(DateTime value) => _createdAtFormat.format(value.toLocal());

Future<void> _reviewDeleteDoc({
  required String collection,
  required String id,
  required String sourceTag,
  required String successToast,
}) async {
  try {
    await firestoreClient.deleteDoc(collection, id, sourceTag: sourceTag);
    toasts.success(successToast);
  } on FirestoreError catch (e, st) {
    logger.e('review delete failed ($sourceTag)', error: e, stackTrace: st);
    toasts.success(
      e.code == 'permission-denied'
          ? "Couldn't delete: permission denied. Check you're signed in with the same account you used to upload."
          : "Couldn't delete. Please try again.",
    );
  }
}
