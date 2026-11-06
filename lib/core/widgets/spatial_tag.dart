import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/wallpaper/wall_spatial.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The Spatial Scene tier of a Prism wall. Null for other sources.
WallSpatial? spatialOf(FeedItemEntity item) => switch (item) {
  PrismFeedItem(:final wallpaper) => wallpaper.spatial,
  _ => null,
};

bool showsSpatialScene(WallSpatialTier? tier) => showSpatialSceneUi && (tier?.suitsSpatialScene ?? false);

/// The Spatial badge at the top end of a grid tile, or null when [showsSpatialScene] is false.
Widget? spatialTagFor(WallSpatialTier? tier) =>
    showsSpatialScene(tier) ? const TileBadges(badges: <Widget>[SpatialTag()]) : null;

/// Stacks the tile overlays. Null for none, the layer itself for one, else a [Stack] that fills the tile. All
/// [TileBadges] layers merge into one row, so a Depth and a Spatial badge sit side by side and never overlap.
Widget? stackTags(List<Widget?> layers) {
  final List<Widget> present = layers.whereType<Widget>().toList();
  final List<TileBadges> badgeLayers = present.whereType<TileBadges>().toList();
  if (badgeLayers.length > 1) {
    present
      ..removeWhere((layer) => layer is TileBadges)
      ..add(TileBadges(badges: <Widget>[for (final layer in badgeLayers) ...layer.badges]));
  }
  if (present.isEmpty) return null;
  if (present.length == 1) return present.single;
  return Stack(fit: StackFit.expand, children: present);
}

/// A 24 point icon badge on a wallpaper tile: a black scrim circle with a white 14 point icon, read as [label].
/// Black and white are fixed on purpose: the badge sits on an image, not on the page. Has no position.
class TileBadge extends StatelessWidget {
  const TileBadge({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  static const double size = 24;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, size: 14, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Puts [badges] in a row at the top end of a tile, 8 points in. Must be a direct child of the tile's [Stack].
class TileBadges extends StatelessWidget {
  const TileBadges({super.key, required this.badges});

  final List<Widget> badges;

  static const double inset = 8;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: inset,
      end: inset,
      child: IgnorePointer(
        child: Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: badges),
      ),
    );
  }
}

/// Has no position. Use [spatialTagFor] to put it on a grid tile.
class SpatialTag extends StatelessWidget {
  const SpatialTag({super.key});

  @override
  Widget build(BuildContext context) =>
      TileBadge(icon: Icons.view_in_ar_rounded, label: context.l10n.coreSpatialBadgeSemantic);
}
