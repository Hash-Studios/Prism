import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:flutter/material.dart';

Future<void> showStreakDetailsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).primaryColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) {
      return const _StreakDetailsSheet();
    },
  );
}

class _StreakDetailsSheet extends StatelessWidget {
  const _StreakDetailsSheet();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StreakStatus>(
      valueListenable: CoinsService.instance.streakNotifier,
      builder: (context, status, _) {
        final int streakDay = status.active ? status.streakDay.clamp(1, 7) : 0;
        final int nextDay = status.active ? (streakDay >= 7 ? 1 : streakDay + 1) : 1;
        final int nextReward = CoinPolicy.streakTotalRewardForDay(nextDay);
        final bool atRiskToday = status.active && !status.claimedToday;
        final String statusLine = status.claimedToday
            ? 'Claimed today. Tomorrow reward: +$nextReward coins.'
            : atRiskToday
            ? 'Claim today to protect your streak. Reward: +$nextReward coins.'
            : 'Start your streak today. Reward: +$nextReward coins.';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent),
                  const SizedBox(width: 8),
                  Text('Streak Details', style: Theme.of(context).textTheme.displaySmall),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Current day: ${status.active ? streakDay : 0}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(statusLine, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 14),
              Text(
                'Reward Ladder',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List<Widget>.generate(7, (index) {
                  final int day = index + 1;
                  final int total = CoinPolicy.streakTotalRewardForDay(day);
                  final bool isCurrent = status.active && day == streakDay;
                  final bool isUpcoming = day == nextDay;
                  final Color borderColor = isCurrent
                      ? Colors.orangeAccent
                      : isUpcoming
                      ? Colors.lightBlueAccent
                      : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.35);
                  return Container(
                    width: 88,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).hintColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Day $day', style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 2),
                        Text(
                          '+$total',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Text(
                'Day 7 jackpot is +${CoinPolicy.streakTotalRewardForDay(7)} coins.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
