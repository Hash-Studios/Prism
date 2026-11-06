import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// A round swatch for one [PrismPaletteColor]. A thin ring outlines it, so white and light swatches show on any
/// surface. A selected swatch gets a 2-pt ring in the accent colour and a check. With [showName], the colour name sits
/// under the swatch, so the choice does not rest on colour alone.
class PaletteSwatch extends StatelessWidget {
  const PaletteSwatch({
    super.key,
    required this.color,
    required this.onTap,
    this.selected = false,
    this.size = 40,
    this.showName = false,
  });

  final PrismPaletteColor color;
  final VoidCallback onTap;
  final bool selected;
  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String name = prismPaletteColorDisplayName(color, context.l10n);
    final Widget swatch = SizedBox(
      width: size + 8,
      height: size + 8,
      child: Center(
        child: AnimatedContainer(
          duration: context.motion(PrismDurations.fast),
          curve: PrismCurves.enter,
          width: selected ? size + 6 : size,
          height: selected ? size + 6 : size,
          padding: EdgeInsets.all(selected ? 3 : 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: selected
                ? Border.all(color: scheme.primary, width: 2)
                : Border.all(color: scheme.onSurface.withValues(alpha: 0.15)),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.color,
              border: Border.all(color: scheme.onSurface.withValues(alpha: 0.2)),
            ),
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: color.color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          PrismHaptics.selection();
          onTap();
        },
        child: showName
            ? SizedBox(
                width: size + 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    swatch,
                    // The row under the swatches has a fixed height, so the name stops growing at 1.3x text.
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: PrismTextStyles.caption(
                          context,
                        ).copyWith(fontSize: 12, color: selected ? scheme.onSurface : scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              )
            : swatch,
      ),
    );
  }
}
