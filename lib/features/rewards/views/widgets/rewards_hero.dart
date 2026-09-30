import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/features/rewards/views/widgets/streak_cycle_strip.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The streak card: Glint, the streak count, a status line and the 7-day cycle.
class RewardsHero extends StatelessWidget {
  const RewardsHero({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StreakStatus>(
      valueListenable: CoinsService.instance.streakNotifier,
      builder: (context, status, _) => _HeroCard(status: status, isPro: app_state.prismUser.premium),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.status, required this.isPro});

  final StreakStatus status;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool alive = status.active || status.claimedToday;
    final int count = alive ? status.count : 0;
    final GlintMood mood = count == 0
        ? GlintMood.calm
        : status.claimedToday
        ? GlintMood.proud
        : GlintMood.happy;
    final int cycleDay = alive ? status.streakDay.clamp(0, 7) : 0;
    // The day the strip marks as today: the claimed day, or the next one to claim.
    final int todayDay = status.claimedToday ? cycleDay : (cycleDay >= 7 ? 1 : cycleDay + 1);
    final int nextDay = cycleDay >= 7 ? 1 : cycleDay + 1;
    final String statusLine = count == 0
        ? 'Open Prism every day to build a streak.'
        : status.claimedToday
        ? 'Today is done. Come back tomorrow for +${CoinPolicy.streakClaimRewardForDay(nextDay, isPro: isPro)} coins.'
        : 'Open Prism today to keep your streak.';
    final TextStyle caption = PrismTextStyles.caption(context);

    return PrismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Glint(mood: mood),
              const SizedBox(width: PrismSpace.lg),
              Expanded(
                child: Semantics(
                  container: true,
                  label: '$count ${count == 1 ? 'day' : 'days'} streak',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('STREAK', style: PrismTextStyles.eyebrow(context)),
                      const SizedBox(height: PrismSpace.xxs),
                      Wrap(
                        spacing: PrismSpace.xs,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: <Widget>[
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(end: count.toDouble()),
                            duration: context.motion(PrismDurations.slow),
                            curve: PrismCurves.enter,
                            builder: (context, value, _) => Text(
                              '${value.round()}',
                              style: PrismTextStyles.numeral(context, 64).copyWith(letterSpacing: -1),
                            ),
                          ),
                          Text(count == 1 ? 'day' : 'days', style: PrismTextStyles.body(context)),
                        ],
                      ),
                      if (status.best > 0)
                        Text('Best ${status.best} ${status.best == 1 ? 'day' : 'days'}', style: caption),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PrismSpace.sm),
          Text(statusLine, style: PrismTextStyles.body(context)),
          const SizedBox(height: PrismSpace.md),
          StreakCycleStrip(cycleDay: cycleDay, todayDay: todayDay),
          const SizedBox(height: PrismSpace.sm),
          Row(
            children: <Widget>[
              Icon(Icons.card_giftcard_rounded, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: PrismSpace.xs),
              Expanded(child: Text('Finish day 7 for a +${CoinPolicy.streak7Bonus} week bonus', style: caption)),
            ],
          ),
        ],
      ),
    );
  }
}
