import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/spatial_tag.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The "Boosted" badge on a trending tile, or null when the wall has no live boost. It joins the tile's other badges
/// in [stackTags].
Widget? boostedTagFor(PrismWallpaper wall, {DateTime? now}) {
  if (!wall.isBoostedAt(now ?? DateTime.now())) return null;
  return const _BoostedBadge();
}

class _BoostedBadge extends TileBadges {
  const _BoostedBadge() : super(badges: const <Widget>[_BoostedIcon()]);
}

class _BoostedIcon extends StatelessWidget {
  const _BoostedIcon();

  @override
  Widget build(BuildContext context) => TileBadge(icon: Icons.bolt_rounded, label: context.l10n.wallpaperBoostedTag);
}

/// The "Boosted" pill. Place it yourself, for example in the tag slot of a hero card.
class BoostedTag extends StatelessWidget {
  const BoostedTag({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(PrismRadius.pill),
      ),
      child: PrismTag(label: context.l10n.wallpaperBoostedTag, tone: PrismTone.accent, icon: Icons.bolt_rounded),
    );
  }
}
