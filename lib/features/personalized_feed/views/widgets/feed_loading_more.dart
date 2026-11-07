import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/prism_loader.dart';
import 'package:flutter/material.dart';

/// The looping Prism mark under the home grid while the next page loads.
class FeedLoadingMore extends StatelessWidget {
  // ponytail: columns is unused since the skeleton row went; drop it with its two callers
  // (personalized_feed_screen.dart, paged_chip_sliver.dart), which WP2 does not own.
  const FeedLoadingMore({super.key, required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: PrismSpace.xl),
      child: Center(child: PrismLoader()),
    );
  }
}
