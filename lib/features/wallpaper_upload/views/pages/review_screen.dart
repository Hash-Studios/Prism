import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/rejection_feedback.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/review_tile_parts.dart';
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
    return Scaffold(
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
      ),
      backgroundColor: Theme.of(context).primaryColor,
      body: const _WallReview(),
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
              if (snapshot.hasError) return const _ReviewMessage("Couldn't load your rejected submissions.");
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
                                      tooltip: 'Delete wallpaper',
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
