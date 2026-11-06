import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/wallpaper/wall_spatial.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The Spatial Scene tier of a Prism wall. Null for other sources.
WallSpatial? spatialOf(FeedItemEntity item) => switch (item) {
  PrismFeedItem(:final wallpaper) => wallpaper.spatial,
  _ => null,
};

bool showsSpatialScene(WallSpatialTier? tier) => showSpatialSceneUi && (tier?.suitsSpatialScene ?? false);

/// The "Spatial" tag at the bottom end of a grid tile, or null when [showsSpatialScene] is false.
Widget? spatialTagFor(WallSpatialTier? tier) => showsSpatialScene(tier) ? const _PositionedSpatialTag() : null;

/// Stacks the tile overlays. Null for none, the layer itself for one, else a [Stack] that fills the tile.
Widget? stackTags(List<Widget?> layers) {
  final List<Widget> present = layers.whereType<Widget>().toList();
  if (present.isEmpty) return null;
  if (present.length == 1) return present.single;
  return Stack(fit: StackFit.expand, children: present);
}

/// Below this tile width the tag shows only its icon: the heart (44 target) and the full tag would touch.
const double spatialTagIconOnlyBelow = 150;

/// Has no position. Use [spatialTagFor] to put it on a grid tile.
class SpatialTag extends StatelessWidget {
  const SpatialTag({super.key, this.iconOnly = false});

  /// Narrow tiles show only the icon, so the tag never runs into the favourite heart at the other corner.
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.coreSpatialBadgeSemantic,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(PrismRadius.pill),
          ),
          child: iconOnly
              ? SizedBox.square(dimension: 24, child: Icon(Icons.view_in_ar_rounded, size: 14, color: cs.onSurface))
              : PrismTag(label: context.l10n.coreSpatialBadge, icon: Icons.view_in_ar_rounded),
        ),
      ),
    );
  }
}

class _PositionedSpatialTag extends StatelessWidget {
  const _PositionedSpatialTag();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: AlignmentDirectional.bottomEnd,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: SpatialTag(iconOnly: constraints.maxWidth < spatialTagIconOnlyBelow),
            ),
          ),
        ),
      ),
    );
  }
}
