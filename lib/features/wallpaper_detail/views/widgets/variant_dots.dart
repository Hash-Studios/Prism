import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/wallpaper/wallpaper_display_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/variant_group.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The colours of a wall with colour variants, as a row of dots. A dot is the variant's main colour, or a tiny
/// thumbnail when the server has no colour for it. A tap shows that variant.
class VariantDots extends StatelessWidget {
  const VariantDots({super.key, required this.group, required this.selected, required this.onSelect});

  final VariantGroup group;
  final int selected;
  final ValueChanged<int> onSelect;

  static const double target = 44;
  static const double dot = 24;

  static PrismPaletteColor? mainColour(PrismWallpaper wall) {
    final String? id = wall.colors?.firstOrNull;
    if (id == null) return null;
    for (final PrismPaletteColor colour in prismPalette) {
      if (colour.id == id) return colour;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final int count = group.length;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: PrismSpace.xs,
      children: [
        Text(l10n.wallVariantCount(count), style: PrismTextStyles.caption(context)),
        Wrap(
          children: [
            for (var i = 0; i < count; i++)
              _VariantDot(
                wall: group.walls[i],
                selected: i == selected,
                label: switch (mainColour(group.walls[i])) {
                  final PrismPaletteColor colour => l10n.wallVariantDotLabel(
                    i + 1,
                    count,
                    prismPaletteColorDisplayName(colour, l10n),
                  ),
                  null => l10n.wallVariantDotLabelPlain(i + 1, count),
                },
                onTap: () => onSelect(i),
              ),
          ],
        ),
      ],
    );
  }
}

class _VariantDot extends StatelessWidget {
  const _VariantDot({required this.wall, required this.selected, required this.label, required this.onTap});

  final PrismWallpaper wall;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color? colour = VariantDots.mainColour(wall)?.color;
    final String thumbnail = WallpaperDisplaySource.of(PrismFeedItem(id: wall.id, wallpaper: wall)).thumbnail;
    final Widget fill = colour != null
        ? ColoredBox(color: colour)
        : thumbnail.isEmpty
        ? ColoredBox(color: cs.surfaceContainerHighest)
        : CachedNetworkImage(
            cacheManager: PrismImageCache.instance,
            imageUrl: thumbnail,
            fit: BoxFit.cover,
            memCacheWidth: 96,
            placeholder: (_, _) => ColoredBox(color: cs.surfaceContainerHighest),
            errorWidget: (_, _, _) => ColoredBox(color: cs.surfaceContainerHighest),
          );
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: selected ? null : onTap,
      onTapHint: context.l10n.wallVariantDotHint,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected
            ? null
            : () {
                PrismHaptics.selection();
                onTap();
              },
        child: SizedBox.square(
          dimension: VariantDots.target,
          child: Center(
            child: AnimatedContainer(
              duration: context.motion(PrismDurations.fast),
              curve: PrismCurves.move,
              width: VariantDots.dot + 8,
              height: VariantDots.dot + 8,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? cs.onSurface : Colors.transparent, width: 2),
              ),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6), width: 0.5),
                ),
                child: ClipOval(child: fill),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
