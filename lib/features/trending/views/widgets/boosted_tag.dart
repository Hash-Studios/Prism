import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The "Boosted" tag on a trending tile, or null when the wall has no live boost.
Widget? boostedTagFor(PrismWallpaper wall, {DateTime? now}) {
  if (!wall.isBoostedAt(now ?? DateTime.now())) return null;
  return const _PositionedBoostedTag();
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

class _PositionedBoostedTag extends StatelessWidget {
  const _PositionedBoostedTag();

  @override
  Widget build(BuildContext context) {
    return Positioned.directional(
      textDirection: Directionality.of(context),
      start: 6,
      top: 6,
      child: const IgnorePointer(child: BoostedTag()),
    );
  }
}
