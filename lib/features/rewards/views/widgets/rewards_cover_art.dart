import 'dart:ui' show ImageFilter;

import 'package:Prism/core/widgets/glint/cover_mosaic.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// A bundled wallpaper cover for slot [index]. Stable, so a tile always shows the same art.
String rewardsCoverAsset(int index) => kCoverMosaicAssets[index % kCoverMosaicAssets.length];

/// Fills its box with a bundled cover and a bottom scrim, so white text on top keeps AA contrast.
/// Decoration only; screen readers skip it. Put it first in a [Stack].
class RewardsCoverArt extends StatelessWidget {
  const RewardsCoverArt({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Black under the art, so white text stays readable if the asset fails to load.
          const ColoredBox(color: Colors.black),
          Image.asset(asset, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const <double>[0, 0.4, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft blurred wallpaper wash over [child]'s surface. Low opacity keeps the text on [child] readable.
/// It ignores touches, so the card under it stays tappable.
class RewardsCoverWash extends StatelessWidget {
  const RewardsCoverWash({super.key, required this.asset, required this.child, this.opacity = 0.2});

  final String asset;
  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(PrismRadius.lg),
                child: Opacity(
                  opacity: opacity,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Image.asset(asset, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
