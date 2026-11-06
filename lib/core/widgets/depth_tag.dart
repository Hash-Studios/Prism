import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/widgets/spatial_tag.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The Depth Effect tier of a Prism wall. Null for other sources.
WallDepthTier? depthTierOf(FeedItemEntity item) => switch (item) {
  PrismFeedItem(:final wallpaper) => wallpaper.depthTier,
  _ => null,
};

bool showsDepthEffect(WallDepthTier? tier) => showDepthEffectUi && (tier?.supportsDepth ?? false);

/// The Depth badge at the top end of a grid tile, or null when [showsDepthEffect] is false. Pass it to [stackTags]
/// with the Spatial badge so the two share one row.
Widget? depthTagFor(WallDepthTier? tier) =>
    showsDepthEffect(tier) ? const TileBadges(badges: <Widget>[DepthTag()]) : null;

/// Has no position. Use [depthTagFor] to put it on a grid tile.
class DepthTag extends StatelessWidget {
  const DepthTag({super.key});

  @override
  Widget build(BuildContext context) =>
      TileBadge(icon: Icons.layers_rounded, label: context.l10n.coreDepthEffectBadgeSemantic);
}
