import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// "See more" as the last cell of a paged wallpaper grid. It fills its cell and has the tile shape.
class SeeMoreButton extends StatelessWidget {
  const SeeMoreButton({super.key, required this.seeMoreLoader, required this.func});

  final bool seeMoreLoader;
  final VoidCallback func;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PressScale(
      scale: 0.97,
      enabled: !seeMoreLoader,
      child: Material(
        color: cs.onSurface.withValues(alpha: 0.08),
        borderRadius: PrismWallGrid.tileRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: seeMoreLoader ? null : func,
          child: Center(
            child: AnimatedSwitcher(
              duration: context.motion(PrismDurations.fast),
              child: seeMoreLoader
                  ? SizedBox.square(
                      key: const ValueKey<String>('loading'),
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.onSurface),
                    )
                  : Column(
                      key: const ValueKey<String>('label'),
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.add_rounded, size: 22, color: cs.onSurface),
                        const SizedBox(height: PrismSpace.xxs),
                        Text('See more', style: PrismTextStyles.rowTitle(context)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
