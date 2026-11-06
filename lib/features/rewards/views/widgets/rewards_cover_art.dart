import 'package:Prism/core/widgets/glint/cover_mosaic.dart';
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
