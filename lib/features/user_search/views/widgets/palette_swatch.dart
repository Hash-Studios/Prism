import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// A round swatch for one [PrismPaletteColor]. A selected swatch gets a ring in the accent colour.
class PaletteSwatch extends StatelessWidget {
  const PaletteSwatch({super.key, required this.color, required this.onTap, this.selected = false, this.size = 40});

  final PrismPaletteColor color;
  final VoidCallback onTap;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: prismPaletteColorDisplayName(color, context.l10n),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          PrismHaptics.selection();
          onTap();
        },
        child: SizedBox(
          width: size + 8,
          height: size + 8,
          child: Center(
            child: AnimatedContainer(
              duration: context.motion(const Duration(milliseconds: 120)),
              width: selected ? size + 6 : size,
              height: selected ? size + 6 : size,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 2),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.color,
                  border: Border.all(color: scheme.onSurface.withValues(alpha: 0.12)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
