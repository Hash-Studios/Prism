import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/coins/streak_pill.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

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
            final bool isEarn = delta > 0;
            final bool isSpend = delta < 0;
            final Color bgColor = isEarn
                ? Colors.green.withValues(alpha: 0.2)
                : isSpend
                ? Colors.red.withValues(alpha: 0.2)
                : Theme.of(context).hintColor;
            return AnimatedScale(
              scale: delta == 0 ? 1 : 1.06,
              duration: const Duration(milliseconds: 220),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (showStreak) ...[const StreakPill(compact: true), const SizedBox(width: 8)],
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        if (isLow) {
                          CoinsService.instance.logLowBalanceNudge(
                            sourceTag: sourceTag,
                            requiredCoins: CoinPolicy.lowBalanceNudgeThreshold,
                          );
                        }
                        context.router.push(const CoinTransactionsRoute());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isLow
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.secondary,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PrismCoinIcon(size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '$balance',
                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (delta != 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                isEarn ? '+$delta' : '$delta',
                                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                  color: isEarn ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
