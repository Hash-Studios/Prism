import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/utils/localized_relative_time.dart';
import 'package:Prism/core/wallpaper/wall_live.dart';
import 'package:Prism/core/widgets/live_tag.dart';
import 'package:Prism/core/widgets/live_wall_video.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/views/widgets/wall_resubmission_notice.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// What the review queue shows for a live wall. A still wall has no state.
enum LiveReviewState {
  /// The server has not checked the video yet.
  checking,

  /// The server refused the video. The admin can only reject it.
  failed,

  /// The server checked the video, so it plays.
  ready,
}

/// Reads `kind` and `live` from a wall document. Null for a still wall.
LiveReviewState? liveReviewStateOf(Map<String, dynamic> data) {
  if (WallKind.parse(data['kind']) != WallKind.live) return null;
  final Object? live = data['live'];
  final Object? verified = live is Map ? live['verified'] : null;
  if (verified == null) return LiveReviewState.checking;
  if (verified != true) return LiveReviewState.failed;
  return WallLive.parse(kind: data['kind'], value: live) == null ? null : LiveReviewState.ready;
}

/// A small pill on a review card: the server check is running, or it refused the video.
class LiveReviewPill extends StatelessWidget {
  const LiveReviewPill({super.key, required this.state});

  /// [LiveReviewState.checking] or [LiveReviewState.failed].
  final LiveReviewState state;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool failed = state == LiveReviewState.failed;
    final Widget leading = failed
        ? Icon(Icons.error_outline_rounded, color: cs.error, size: 14)
        : const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2));
    final Widget pill = DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(PrismRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm, vertical: PrismSpace.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            leading,
            const SizedBox(width: PrismSpace.xs),
            Flexible(
              child: Text(
                failed ? context.l10n.adminLiveFailed : context.l10n.adminLiveChecking,
                style: PrismTextStyles.caption(context),
              ),
            ),
          ],
        ),
      ),
    );
    return failed ? Semantics(liveRegion: true, child: pill) : pill;
  }
}

/// One wallpaper in the swipe stack. The wallpaper fills the card; the title, category and creator sit on a scrim.
class SwipeWallpaperCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String category;
  final String authorName;
  final String authorPhoto;
  final DateTime? uploadedAt;
  final bool isTopCard;
  final String? wallDocId;

  /// The wall document's raw data. Reads `kind` and `live` for a live wall. Null for a still wall.
  final Map<String, dynamic>? liveData;

  /// Space around the card. The stamp overlay uses the same margin so the two line up.
  static const EdgeInsets margin = EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: PrismSpace.xs);

  const SwipeWallpaperCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.category,
    required this.authorName,
    required this.authorPhoto,
    this.uploadedAt,
    this.isTopCard = true,
    this.wallDocId,
    this.liveData,
  });

  factory SwipeWallpaperCard.fromDocument(FirestoreDocument wall, {bool isTopCard = true}) {
    final DateTime? uploadedAt = wall.createdAt;
    return SwipeWallpaperCard(
      imageUrl: wall.wallpaperThumb.isNotEmpty ? wall.wallpaperThumb : wall.wallpaperUrl,
      title: wall.data()['title']?.toString() ?? '',
      category: wall.data()['category']?.toString() ?? '',
      authorName: wall.by,
      authorPhoto: wall.userPhoto,
      uploadedAt: uploadedAt,
      isTopCard: isTopCard,
      wallDocId: wall.id,
      liveData: wall.data(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextStyle onImage = PrismTextStyles.caption(context).copyWith(color: Colors.white);
    final Map<String, dynamic>? data = liveData;
    final LiveReviewState? live = data == null ? null : liveReviewStateOf(data);
    final WallLive? wallLive = live == LiveReviewState.ready
        ? WallLive.parse(kind: data!['kind'], value: data['live'])
        : null;
    final int? durationMs = wallLive?.durationMs;

    final Widget poster = CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => const PrismSkeleton(child: PrismBone(height: double.infinity, radius: 0)),
      errorWidget: (context, url, error) => ColoredBox(
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.broken_image_outlined, color: cs.onSurface.withValues(alpha: 0.5), size: 48),
      ),
    );

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (wallLive != null)
              LiveWallVideo(live: wallLive, poster: poster, surface: LiveSurface.review)
            else
              poster,
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
            // Top end: the swipe screen puts its depth pill at the top start.
            if (live != null)
              PositionedDirectional(
                top: 12,
                end: 12,
                child: live == LiveReviewState.ready ? const LiveTag() : LiveReviewPill(state: live),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(PrismSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (wallDocId != null) WallResubmissionNotice(wallDocId: wallDocId!, onImage: true),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(PrismRadius.pill),
                      ),
                      child: Text(
                        category.isNotEmpty ? category : context.l10n.adminGeneral,
                        style: onImage.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (durationMs != null) ...[
                      const SizedBox(height: PrismSpace.xxs),
                      Text(context.l10n.adminLiveFacts((durationMs / 1000).toStringAsFixed(1)), style: onImage),
                    ],
                    const SizedBox(height: PrismSpace.xs),
                    Text(
                      title.isNotEmpty ? title : context.l10n.adminUntitled,
                      style: PrismTextStyles.sheetHeadline(context).copyWith(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: PrismSpace.sm),
                    Row(
                      children: [
                        PrismAvatar(url: authorPhoto, name: authorName, size: 32),
                        const SizedBox(width: PrismSpace.xs),
                        Expanded(
                          child: Text(
                            authorName.isNotEmpty ? authorName : context.l10n.adminAnonymous,
                            style: PrismTextStyles.rowTitle(context).copyWith(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (uploadedAt != null) ...<Widget>[
                      const SizedBox(height: PrismSpace.xxs),
                      Text(
                        localizedRelativeTime(context.l10n, uploadedAt!, locale: Localizations.localeOf(context)),
                        style: onImage.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!isTopCard) ColoredBox(color: Colors.black.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
