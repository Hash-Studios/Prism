import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Skeleton for a wallpaper grid. It uses the shared [PrismWallGrid] layout, so content lands where the skeleton was.
class LoadingCards extends StatelessWidget {
  const LoadingCards({
    super.key,
    this.childAspectRatio,
    this.borderRadius = PrismWallGrid.tileRadius,
    this.columns,
    this.useFeedLayout = false,
  });

  final double? childAspectRatio;
  final BorderRadius borderRadius;
  final int? columns;

  /// Lays the skeleton out like the home grid: [PrismFeedLayout.gridPadding] side margin and
  /// [PrismFeedLayout.gridSpacing] gaps. It never scrolls by itself.
  final bool useFeedLayout;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: PulsePlaceholder(
          builder: (context, _) => GridView.builder(
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            padding: useFeedLayout ? PrismFeedLayout.gridPadding : PrismWallGrid.padding,
            itemCount: 18,
            shrinkWrap: true,
            gridDelegate: PrismWallGrid.delegate(
              context,
              columns: columns,
              aspectRatio: childAspectRatio,
              spacing: useFeedLayout ? PrismFeedLayout.gridSpacing : PrismWallGrid.spacing,
            ),
            itemBuilder: (context, index) => PulseFill(borderRadius: borderRadius),
          ),
        ),
      ),
    );
  }
}
