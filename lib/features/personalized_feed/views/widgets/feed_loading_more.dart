import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// A row of skeleton tiles under a feed while the next page loads.
class FeedLoadingMore extends StatelessWidget {
  const FeedLoadingMore({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: PrismFeedLayout.loadingStatePadding,
      child: SizedBox(
        height: 120,
        child: PulsePlaceholder(
          builder: (context, _) => const Row(
            children: <Widget>[
              Expanded(child: PulseFill()),
              SizedBox(width: 8),
              Expanded(child: PulseFill()),
              SizedBox(width: 8),
              Expanded(child: PulseFill()),
            ],
          ),
        ),
      ),
    );
  }
}
