import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:flutter/material.dart';

/// The Depth Effect tier of a Prism wall. Null for other sources.
WallDepthTier? depthTierOf(FeedItemEntity item) => switch (item) {
  PrismFeedItem(:final wallpaper) => wallpaper.depthTier,
  _ => null,
};

bool showsDepthEffect(WallDepthTier? tier) => showDepthEffectUi && (tier?.supportsDepth ?? false);

/// The "Depth" tag at the bottom start of a grid tile, or null when [showsDepthEffect] is false.
Widget? depthTagFor(WallDepthTier? tier) => showsDepthEffect(tier) ? const _PositionedDepthTag() : null;

/// Has no position. Use [depthTagFor] to put it on a grid tile.
class DepthTag extends StatelessWidget {
  const DepthTag({super.key});

  static const String semanticLabel = 'Works with Depth Effect';

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(PrismRadius.pill),
          ),
          child: const PrismTag(label: 'Depth', icon: Icons.layers_rounded),
        ),
      ),
    );
  }
}

class _PositionedDepthTag extends StatelessWidget {
  const _PositionedDepthTag();

  @override
  Widget build(BuildContext context) {
    return Positioned.directional(
      textDirection: Directionality.of(context),
      start: 6,
      bottom: 6,
      child: const IgnorePointer(child: DepthTag()),
    );
  }
}
