import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

class LoadingCards extends StatelessWidget {
  const LoadingCards({
    super.key,
    this.childAspectRatio = 0.6625,
    this.borderRadius = BorderRadius.zero,
    this.useFeedLayout = false,
  });

  final double childAspectRatio;
  final BorderRadius borderRadius;

  /// Matches the wallpaper grids: the same columns and tile ratio, and no gaps. Use it inside a feed's own scroll
  /// view, so the layout does not jump when the tiles arrive. It does not scroll by itself.
  final bool useFeedLayout;

  @override
  Widget build(BuildContext context) {
    return PulsePlaceholder(
      builder: (context, _) => GridView.builder(
        primary: false,
        physics: useFeedLayout ? const NeverScrollableScrollPhysics() : null,
        padding: useFeedLayout ? EdgeInsets.zero : const EdgeInsets.fromLTRB(5, 4, 5, 4),
        itemCount: 24,
        shrinkWrap: true,
        gridDelegate: useFeedLayout
            ? SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: wallpaperGridColumns(MediaQuery.sizeOf(context).width),
                childAspectRatio: PrismFeedLayout.gridTileAspectRatio,
              )
            : SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
                childAspectRatio: childAspectRatio,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
        itemBuilder: (context, index) => PulseFill(borderRadius: borderRadius),
      ),
    );
  }
}
