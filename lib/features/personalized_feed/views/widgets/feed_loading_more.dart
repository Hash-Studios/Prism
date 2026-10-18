import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:flutter/material.dart';

/// A row of square skeleton tiles under the full-bleed home grid while the next page loads.
class FeedLoadingMore extends StatelessWidget {
  const FeedLoadingMore({super.key, required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context) {
    return PrismSkeleton(
      child: Padding(
        padding: const EdgeInsets.only(top: PrismFeedLayout.gridSpacing),
        child: Row(
          children: <Widget>[
            for (int i = 0; i < columns; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: PrismFeedLayout.gridSpacing),
              const Expanded(
                child: AspectRatio(aspectRatio: PrismFeedLayout.gridTileAspectRatio, child: PulseFill()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
