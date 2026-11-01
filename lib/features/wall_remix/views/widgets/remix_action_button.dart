import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// The Remix action on a Prism wall. It opens the AI tab seeded with the wall's prompt and style.
class RemixActionButton extends StatelessWidget {
  const RemixActionButton({required this.seed, super.key});

  final AiRemixSeed seed;

  @override
  Widget build(BuildContext context) {
    return CircularMenuButton(
      label: context.l10n.wallRemixAction,
      isLoading: false,
      onTap: () {
        PrismHaptics.tap();
        analytics.track(RemixTappedEvent(sourceWallType: seed.sourceType));
        context.router.root.push(AiTabRoute(remixSeed: seed));
      },
      child: const Icon(Icons.auto_awesome_rounded),
    );
  }
}
