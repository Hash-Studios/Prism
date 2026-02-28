import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

class PremiumList extends StatelessWidget {
  void _trackBuyPremiumTap() {
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.profilePremiumList,
          action: AnalyticsActionValue.buyPremiumTapped,
          sourceContext: 'profile_premium_list_buy_premium',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        if (app_state.prismUser.premium == true)
          Container()
        else
          ListTile(
            onTap: () {
              _trackBuyPremiumTap();
              if (app_state.prismUser.loggedIn == false) {
                googleSignInPopUp(context, () {
                  if (app_state.prismUser.premium == true) {
                    main.RestartWidget.restartApp(context);
                  } else {
                    PaywallOrchestrator.instance.present(
                      context,
                      placement: PaywallPlacement.mainUpsell,
                      source: 'profile_premium_list',
                    );
                  }
                });
              } else {
                PaywallOrchestrator.instance.present(
                  context,
                  placement: PaywallPlacement.mainUpsell,
                  source: 'profile_premium_list',
                );
              }
            },
            leading: const Icon(JamIcons.instant_picture_f),
            title: Text(
              "Buy Premium",
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w500,
                fontFamily: "Proxima Nova",
              ),
            ),
            subtitle: const Text("Get unlimited setups and filters.", style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}
