import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

class StatsEntryButton extends StatelessWidget {
  const StatsEntryButton({super.key, required this.source, this.visible = true});

  final String source;
  final bool visible;

  @override
  Widget build(BuildContext context) => visible
      ? TextButton.icon(
          onPressed: () => context.router.push(CreatorStatsRoute(source: source)),
          icon: const Icon(Icons.bar_chart),
          label: Text(context.l10n.statsEntry),
        )
      : const SizedBox.shrink();
}
