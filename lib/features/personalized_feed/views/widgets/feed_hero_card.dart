import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The frame for a full-bleed home carousel page: an edge-to-edge image with a bottom scrim, text at the bottom left,
/// and optional [tag] (top left) and [badge] (top right) chips. The whole page is one tap target.
///
/// The page has square corners and no outline, so it has no press scale either: a scaled edge-to-edge page would show
/// the background at its sides.
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
    this.textEndInset = 0,
  });

  final Widget image;
  final String semanticLabel;
  final VoidCallback onTap;
  final String? title;
  final String? subtitle;
  final Widget? tag;
  final Widget? badge;

  /// Extra room kept free at the end of the bottom text, for a control a parent draws over the card.
  final double textEndInset;

  @override
  Widget build(BuildContext context) {
    final String? heading = title?.trim().isEmpty ?? true ? null : title!.trim();
    final String? support = subtitle?.trim().isEmpty ?? true ? null : subtitle!.trim();
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(
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
                  right: PrismSpace.md + textEndInset,
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
                            style: PrismTextStyles.body(context).copyWith(color: Colors.white.withValues(alpha: 0.85)),
                          ),
                      ],
                    ),
                  ),
                ),
              if (tag != null) Positioned(left: PrismSpace.sm, top: PrismSpace.sm, child: tag!),
              if (badge != null) Positioned(right: PrismSpace.sm, top: PrismSpace.sm, child: badge!),
            ],
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
