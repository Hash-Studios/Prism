import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Icon-only entry to the creator stats page. [onImage] draws it on a scrim for headers over a cover.
class StatsEntryButton extends StatelessWidget {
  const StatsEntryButton({super.key, required this.source, this.visible = true, this.onImage = false});

  final String source;
  final bool visible;
  final bool onImage;

  @override
  Widget build(BuildContext context) => visible
      ? PrismIconButton(
          icon: Icons.bar_chart_rounded,
          tooltip: context.l10n.statsEntry,
          onImage: onImage,
          onPressed: () => context.router.push(CreatorStatsRoute(source: source)),
        )
      : const SizedBox.shrink();
}
