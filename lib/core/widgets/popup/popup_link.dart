import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';

LinkDestinationValue _destination(String link) {
  final String lower = link.toLowerCase();
  if (lower.contains('github.com')) {
    return LinkDestinationValue.github;
  }
  if (lower.contains('play.google.com')) {
    return LinkDestinationValue.playStore;
  }
  if (lower.contains('twitter.com')) {
    return LinkDestinationValue.twitter;
  }
  if (lower.contains('instagram.com')) {
    return LinkDestinationValue.instagram;
  }
  if (lower.contains('t.me') || lower.contains('telegram')) {
    return LinkDestinationValue.telegram;
  }
  if (lower.contains('mailto:') || lower.contains('@gmail.com')) {
    return LinkDestinationValue.email;
  }
  return LinkDestinationValue.external;
}

/// Opens [link] and tracks the tap and the result, the same way the about screen's link chips do.
Future<void> openPopupLink(BuildContext context, {required String link, required String label}) async {
  final String sourceContext = 'about_screen_action_chip_${label.toLowerCase()}';
  unawaited(
    analytics.track(
      SurfaceActionTappedEvent(
        surface: AnalyticsSurfaceValue.aboutScreen,
        action: AnalyticsActionValue.actionChipTapped,
        sourceContext: sourceContext,
      ),
    ),
  );
  final String target = link.contains('@gmail.com') ? 'mailto:$link' : link;
  final bool launched = await openPrismLink(context, target);
  unawaited(
    analytics.track(
      ExternalLinkOpenResultEvent(
        surface: AnalyticsSurfaceValue.aboutScreen,
        destination: _destination(link),
        result: launched ? EventResultValue.success : EventResultValue.failure,
        reason: launched ? null : AnalyticsReasonValue.error,
        sourceContext: sourceContext,
      ),
    ),
  );
}

/// A pill with an icon that opens [link].
class PopupLinkChip extends StatelessWidget {
  const PopupLinkChip({super.key, required this.icon, required this.label, required this.link});

  final IconData icon;
  final String label;
  final String link;

  @override
  Widget build(BuildContext context) {
    return PrismChip(
      icon: icon,
      label: label,
      onTap: () => openPopupLink(context, link: link, label: label),
    );
  }
}
