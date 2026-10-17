import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/prism/prism_bits.dart';
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
        ? nextDay == 7
              ? 'Today is done. Come back tomorrow for your day 7 chest.'
              : 'Today is done. Come back tomorrow for +${CoinPolicy.streakClaimRewardForDay(nextDay, isPro: isPro)} coins.'
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
          StreakCycleStrip(cycleDay: cycleDay, streakCount: count, todayDay: todayDay),
          const SizedBox(height: PrismSpace.sm),
          Row(
            children: <Widget>[
              Icon(Icons.card_giftcard_rounded, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: PrismSpace.xs),
              Expanded(
                child: Text(
                  'Finish day 7 for a chest of +${CoinPolicy.streakChestMin} to +${CoinPolicy.streakChestMax}',
                  style: caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: PrismSpace.md),
          Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
          const SizedBox(height: PrismSpace.md),
          const _RankBlock(),
        ],
      ),
    );
  }
}

/// The rank chip and a thin bar to the next rank.
class _RankBlock extends StatelessWidget {
  const _RankBlock();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<XpStatus>(
      valueListenable: CoinsService.instance.xpNotifier,
      builder: (context, status, _) {
        final Rank rank = status.rank;
        final RankDef? next = rank.next;
        final String caption = next == null
            ? 'Prism rank'
            : '${_grouped(status.xp)} / ${_grouped(next.min)} XP to ${_rankTitle(next.id)}';
        return Semantics(
          container: true,
          label: '${_rankTitle(rank.id)} rank, $caption',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  PrismTag(label: _rankTitle(rank.id), tone: PrismTone.accent, icon: Icons.military_tech_outlined),
                  const SizedBox(width: PrismSpace.sm),
                  Expanded(child: Text(caption, style: PrismTextStyles.caption(context))),
                ],
              ),
              const SizedBox(height: PrismSpace.xs),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: rank.progress),
                duration: context.motion(PrismDurations.slow),
                curve: PrismCurves.enter,
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(PrismRadius.pill),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    color: cs.primary,
                    backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _rankTitle(String id) => id.isEmpty ? id : '${id[0].toUpperCase()}${id.substring(1)}';

/// 1240 becomes "1 240" with a no-break space, so a number never wraps in the middle.
String _grouped(int value) => value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '\u00A0');
