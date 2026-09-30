import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/prism/prism_bits.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/core/widgets/prism/prism_skeleton.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/rejection_feedback.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/review_photo_preview.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/review_tile_parts.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One upload in "Your uploads": a thumbnail, its review status, the file facts and the actions. A rejected upload
/// also shows the reviewer's reason.
class WallTile extends StatelessWidget {
  const WallTile(this.wallpaper, {super.key, required this.rejected});

  final FirestoreDocument wallpaper;
  final bool rejected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final DateTime? createdAt = wallpaper.createdAt;
    final String facts = _formatFacts(wallpaper.resolution, wallpaper.size);
    return PrismCard(
      padding: const EdgeInsets.all(PrismSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Thumbnail(wallpaper: wallpaper),
              const SizedBox(width: PrismSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    PrismTag(
                      label: rejected ? 'Rejected' : 'In review',
                      tone: rejected ? PrismTone.danger : PrismTone.warning,
                      icon: rejected ? Icons.close_rounded : Icons.schedule_rounded,
                    ),
                    if (createdAt != null) ...<Widget>[
                      const SizedBox(height: PrismSpace.xs),
                      Text(_formatCreatedAt(createdAt), style: PrismTextStyles.caption(context)),
                    ],
                    if (facts.isNotEmpty) ...<Widget>[
                      const SizedBox(height: PrismSpace.xxs),
                      Text(facts, style: PrismTextStyles.caption(context)),
                    ],
                    const SizedBox(height: PrismSpace.xs),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ReviewDownloadButton(
                            link: wallpaper.wallpaperUrl,
                            kind: SaveMediaKind.wallpaper,
                            event: DownloadOwnWallEvent(link: wallpaper.wallpaperUrl),
                            successMessage: 'Wallpaper saved to Pictures/Prism',
                            failLogSuffix: rejected ? 'rejected wall download' : 'review wall download',
                            showNotification: true,
                          ),
                          PrismIconButton(
                            icon: Icons.delete_outline_rounded,
                            tooltip: 'Delete wallpaper',
                            color: cs.error,
                            onPressed: () => showDeleteConfirm(
                              context,
                              title: 'Delete this wallpaper?',
                              onConfirm: () => _deleteDoc(
                                collection: rejected ? FirebaseCollections.rejectedWalls : FirebaseCollections.walls,
                                id: wallpaper.id,
                                sourceTag: rejected ? 'review.rejectedWall.delete' : 'review.wall.delete',
                                successToast: 'Wallpaper deleted.',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (rejected) RejectionFeedback(reason: wallpaper.data()['rejectionReason']?.toString()),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.wallpaper});

  final FirestoreDocument wallpaper;

  static const double _width = 72;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(PrismRadius.sm);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final Widget fallback = ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(child: Icon(Icons.broken_image_rounded, color: cs.onSurface.withValues(alpha: 0.3))),
    );
    return Semantics(
      button: true,
      label: 'View wallpaper',
      excludeSemantics: true,
      onTap: () => _open(context),
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _open(context),
          child: SizedBox(
            width: _width,
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: CachedNetworkImage(
                    imageUrl: wallpaper.wallpaperThumb,
                    fit: BoxFit.cover,
                    memCacheWidth: (_width * dpr).round(),
                    placeholder: (_, _) => const PrismSkeleton(child: PrismBone(height: _width * 16 / 9, radius: 0)),
                    errorWidget: (_, _, _) => fallback,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) =>
      showReviewPhotoPreview(context, url: wallpaper.wallpaperUrl, thumbUrl: wallpaper.wallpaperThumb);
}

final DateFormat _createdAtFormat = DateFormat('d MMM y, h:mm a');

String _formatCreatedAt(DateTime value) => _createdAtFormat.format(value.toLocal());

/// "1440x3200" and "2MB" become "1440 x 3200 · 2 MB". A part that is empty is left out.
String _formatFacts(String resolution, String size) {
  final String res = resolution.replaceFirstMapped(RegExp(r'^(\d+)x(\d+)$'), (m) => '${m[1]} x ${m[2]}');
  final String file = size.replaceFirstMapped(RegExp(r'^([\d.]+)\s*([KMG]B)$'), (m) => '${m[1]} ${m[2]}');
  return <String>[res, file].where((String part) => part.isNotEmpty).join(' · ');
}

Future<void> _deleteDoc({
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
    toasts.error(
      e.code == 'permission-denied'
          ? "Couldn't delete. Sign in with the account you used to upload, then try again."
          : "Couldn't delete. Try again.",
    );
  }
}
