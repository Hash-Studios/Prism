import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One category in the interests grid: an image with its name bottom-left on a scrim. Selected tiles get a 2 point
/// accent border, a tick and a slight shrink.
class InterestCategoryTile extends StatelessWidget {
  const InterestCategoryTile({
    super.key,
    required this.name,
    required this.isSelected,
    required this.onTap,
    this.imageUrl,
  });

  final String name;
  final String? imageUrl;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(PrismRadius.sm);
    final Widget placeholder = ColoredBox(color: cs.surfaceContainerHigh);
    final String? url = imageUrl;
    void select() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: name,
      onTap: select,
      child: ExcludeSemantics(
        child: PressScale(
          child: AnimatedScale(
            scale: isSelected ? 0.96 : 1,
            duration: context.motion(PrismDurations.fast),
            curve: PrismCurves.enter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: select,
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (url == null || url.isEmpty)
                      placeholder
                    else
                      CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        fadeInDuration: context.motion(PrismDurations.fast),
                        placeholder: (_, _) => placeholder,
                        errorWidget: (_, _, _) => placeholder,
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Colors.transparent, Colors.black.withValues(alpha: 0.65)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: PrismSpace.xs,
                      right: PrismSpace.xs,
                      bottom: PrismSpace.xs,
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PrismTextStyles.rowTitle(
                          context,
                        ).copyWith(fontSize: 13, color: Colors.white, height: 1.2),
                      ),
                    ),
                    Positioned(
                      top: PrismSpace.xs,
                      right: PrismSpace.xs,
                      child: AnimatedOpacity(
                        duration: context.motion(PrismDurations.fast),
                        opacity: isSelected ? 1 : 0,
                        child: AnimatedScale(
                          duration: context.motion(PrismDurations.fast),
                          curve: PrismCurves.pop,
                          scale: isSelected ? 1 : 0.8,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                            child: Icon(Icons.check_rounded, color: cs.onPrimary, size: 15),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: AnimatedContainer(
                        duration: context.motion(PrismDurations.fast),
                        curve: PrismCurves.enter,
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          border: Border.all(color: isSelected ? cs.primary : Colors.transparent, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
