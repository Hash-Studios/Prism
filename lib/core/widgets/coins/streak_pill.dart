import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/streak_details_sheet.dart';
import 'package:flutter/material.dart';

class StreakPill extends StatelessWidget {
  const StreakPill({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!app_state.prismUser.loggedIn) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<StreakStatus>(
      valueListenable: CoinsService.instance.streakNotifier,
      builder: (context, status, _) {
        final int streakDay = status.streakDay.clamp(0, 7);
        final bool active = status.active;
        final int nextDay = active ? (streakDay >= 7 ? 1 : streakDay + 1) : 1;
        final int nextReward = CoinPolicy.streakTotalRewardForDay(nextDay);
        final String nextLabel = compact ? '+$nextReward' : 'Next +$nextReward';
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => showStreakDetailsSheet(context),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 6 : 8),
              decoration: BoxDecoration(
                color: active ? Colors.orange.withValues(alpha: 0.18) : Theme.of(context).hintColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active ? Colors.orangeAccent : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.45),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.local_fire_department_rounded, size: compact ? 14 : 16, color: Colors.orangeAccent),
                  SizedBox(width: compact ? 4 : 6),
                  Text(
                    '$streakDay',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: compact ? 4 : 8),
                  Text(
                    nextLabel,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
