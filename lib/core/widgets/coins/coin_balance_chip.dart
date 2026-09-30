import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/coin_pill.dart';
import 'package:Prism/core/widgets/coins/streak_pill.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// The coin balance in a pill that opens Rewards, with the streak pill beside it when [showStreak] is true.
class CoinBalanceChip extends StatelessWidget {
  const CoinBalanceChip({super.key, required this.sourceTag, this.showStreak = true});

  final String sourceTag;
  final bool showStreak;

  @override
  Widget build(BuildContext context) {
    if (!app_state.prismUser.loggedIn) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<int>(
      valueListenable: CoinsService.instance.balanceNotifier,
      builder: (context, balance, _) {
        return ValueListenableBuilder<int>(
          valueListenable: CoinsService.instance.deltaNotifier,
          builder: (context, delta, _) {
            final bool isLow = !app_state.prismUser.premium && balance < CoinPolicy.lowBalanceNudgeThreshold;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (showStreak) ...<Widget>[const StreakPill(compact: true), const SizedBox(width: PrismSpace.xs)],
                CoinBalancePill(
                  balance: balance,
                  delta: delta,
                  low: isLow,
                  onTap: () {
                    if (isLow) {
                      CoinsService.instance.logLowBalanceNudge(
                        sourceTag: sourceTag,
                        requiredCoins: CoinPolicy.lowBalanceNudgeThreshold,
                      );
                    }
                    context.router.push(RewardsRoute());
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
