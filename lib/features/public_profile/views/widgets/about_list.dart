import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

class AboutList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(JamIcons.info),
      title: Text(
        "About Prism",
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w500,
          fontFamily: "Proxima Nova",
        ),
      ),
      subtitle: const Text("GitHub, website & more!", style: TextStyle(fontSize: 12)),
      trailing: const Icon(JamIcons.chevron_right),
      onTap: () {
        unawaited(
          analytics.track(
            SurfaceActionTappedEvent(
              surface: AnalyticsSurfaceValue.profileAboutList,
              action: AnalyticsActionValue.actionChipTapped,
              sourceContext: 'profile_about_list_open_about',
            ),
          ),
        );
        context.router.push(const AboutRoute());
      },
    );
  }
}
