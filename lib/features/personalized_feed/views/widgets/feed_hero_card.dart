import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The card frame for a home carousel page: a clipped image with a bottom scrim, text at the bottom left, and
/// optional [tag] (top left) and [badge] (top right) chips. The whole card is one tap target.
class FeedHeroCard extends StatelessWidget {
  const FeedHeroCard({
    super.key,
    required this.image,
    required this.semanticLabel,
    required this.onTap,
    this.title,
    this.subtitle,
    this.tag,
    this.badge,
  });

  final Widget image;
  final String semanticLabel;
  final VoidCallback onTap;
  final String? title;
  final String? subtitle;
  final Widget? tag;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final BorderRadius radius = BorderRadius.circular(PrismRadius.lg);
    final String? heading = title?.trim().isEmpty ?? true ? null : title!.trim();
    final String? support = subtitle?.trim().isEmpty ?? true ? null : subtitle!.trim();
    return PressScale(
      scale: 0.98,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ExcludeSemantics(
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  image,
                  // The scrim and text never take a tap, so the image's own controls (retry) still work.
                  if (heading != null || support != null)
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const <double>[0.4, 1],
                            colors: <Color>[Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                          ),
                        ),
                      ),
                    ),
                  if (heading != null || support != null)
                    Positioned(
                      left: PrismSpace.md,
                      right: PrismSpace.md,
                      bottom: PrismSpace.md,
                      child: IgnorePointer(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (heading != null)
                              Text(
                                heading,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PrismTextStyles.cardTitle(context).copyWith(color: Colors.white),
                              ),
                            if (support != null)
                              Text(
                                support,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PrismTextStyles.body(
                                  context,
                                ).copyWith(color: Colors.white.withValues(alpha: 0.85)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (tag != null) Positioned(left: PrismSpace.sm, top: PrismSpace.sm, child: tag!),
                  if (badge != null) Positioned(right: PrismSpace.sm, top: PrismSpace.sm, child: badge!),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        border: Border.all(color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.08)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small gold star pill that marks a premium wallpaper.
class PremiumStarBadge extends StatelessWidget {
  const PremiumStarBadge({super.key});

  /// The design system's warning status colour, used here as a gold.
  static const Color _gold = Color(0xFFFFB454);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Premium',
      child: DecoratedBox(
        decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(PrismRadius.pill)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Icon(Icons.star_rounded, size: 14, color: Colors.black.withValues(alpha: 0.8)),
        ),
      ),
    );
  }
}
