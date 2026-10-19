import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Links to the weekly Leaderboard and, while the flag is on, the weekly Draw.
class RewardsLinksSection extends StatelessWidget {
  const RewardsLinksSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EconomyConfig>(
      valueListenable: EconomyConfig.notifier,
      builder: (context, config, _) => Padding(
        padding: const EdgeInsets.only(top: PrismSpace.xxl),
        child: PrismGroup(
          children: <Widget>[
            PrismRow(
              icon: Icons.leaderboard_outlined,
              title: context.l10n.economyLeaderboardTitle,
              subtitle: context.l10n.economyWeeklyXpFriendsEveryone,
              onTap: () {
                PrismHaptics.tap();
                context.router.root.push(const LeaderboardRoute());
              },
            ),
            if (config.flags.drawEnabled)
              PrismRow(
                icon: Icons.confirmation_number_outlined,
                title: context.l10n.economyWeeklyDraw,
                subtitle: context.l10n.economyDrawTicketCost(CoinPolicy.drawTicket),
                onTap: () {
                  PrismHaptics.tap();
                  context.router.root.push(const DrawRoute());
                },
              ),
          ],
        ),
      ),
    );
  }
}
