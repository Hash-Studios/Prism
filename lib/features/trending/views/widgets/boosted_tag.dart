import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';

/// The "Boosted" tag on a trending tile, or null when the wall has no live boost.
Widget? boostedTagFor(PrismWallpaper wall, {DateTime? now}) {
  if (!wall.isBoostedAt(now ?? DateTime.now())) return null;
  return const _BoostedTag();
}

class _BoostedTag extends StatelessWidget {
  const _BoostedTag();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Positioned.directional(
      textDirection: Directionality.of(context),
      start: 6,
      top: 6,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(PrismRadius.pill),
          ),
          child: const PrismTag(label: 'Boosted', tone: PrismTone.accent, icon: Icons.bolt_rounded),
        ),
      ),
    );
  }
}
