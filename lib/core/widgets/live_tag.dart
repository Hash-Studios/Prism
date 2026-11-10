import 'package:Prism/core/wallpaper/wall_live.dart';
import 'package:Prism/core/widgets/live_wall_video.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The kind of a feed item. Only Prism walls can be live.
WallKind kindOf(FeedItemEntity item) => switch (item) {
  PrismFeedItem(:final wallpaper) => wallpaper.kind,
  _ => WallKind.still,
};

/// The "Live" tag at the top start of a grid tile, or null for a still wall.
Widget? liveTagFor(WallKind kind) => kind == WallKind.live ? const _PositionedLiveTag() : null;

/// For a live wall on a feed grid: its silent loop over the tile image, under the tag. Null for a still wall.
/// The tile keeps drawing the poster below, so [LiveWallVideo] gets an empty poster.
Widget? liveFeedLayerFor(FeedItemEntity item, {BorderRadius? radius}) {
  final WallLive? live = switch (item) {
    PrismFeedItem(:final wallpaper) => wallpaper.live,
    _ => null,
  };
  if (live == null) return null;
  return Stack(
    fit: StackFit.expand,
    children: <Widget>[
      IgnorePointer(
        child: ClipRRect(
          borderRadius: radius ?? BorderRadius.zero,
          child: LiveWallVideo(live: live, poster: const SizedBox.shrink(), surface: LiveSurface.feed),
        ),
      ),
      const _PositionedLiveTag(),
    ],
  );
}

/// Has no position. Use [liveTagFor] on a grid tile.
class LiveTag extends StatelessWidget {
  const LiveTag({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.coreLiveBadgeSemantic,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(PrismRadius.pill),
          ),
          child: PrismTag(label: context.l10n.coreLiveBadge, icon: Icons.motion_photos_on_rounded),
        ),
      ),
    );
  }
}

class _PositionedLiveTag extends StatelessWidget {
  const _PositionedLiveTag();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: Padding(padding: EdgeInsets.all(6), child: LiveTag()),
        ),
      ),
    );
  }
}
