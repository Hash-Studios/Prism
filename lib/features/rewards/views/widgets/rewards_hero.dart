import 'dart:math' as math;

import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/glint/glint.dart';
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
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
    final TextStyle? muted = theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Glint(mood: mood),
                const SizedBox(width: 18),
                Expanded(
                  child: Semantics(
                    container: true,
                    label: '$count ${count == 1 ? 'day' : 'days'} streak',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'STREAK',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6),
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(end: count.toDouble()),
                              duration: context.motion(PrismDurations.slow),
                              curve: PrismCurves.enter,
                              builder: (context, value, _) => Text(
                                '${value.round()}',
                                style: TextStyle(
                                  fontFamily: PrismFonts.fraunces,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 60,
                                  height: 1.05,
                                  letterSpacing: -1,
                                  color: cs.onSurface,
                                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              count == 1 ? 'day' : 'days',
                              style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                        if (status.best > 0)
                          Text('Best ${status.best} ${status.best == 1 ? 'day' : 'days'}', style: muted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(statusLine, style: muted?.copyWith(fontSize: 13)),
            const SizedBox(height: 16),
            _CycleStrip(cycleDay: cycleDay, todayDay: todayDay),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Icon(Icons.card_giftcard_rounded, size: 15, color: cs.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 7),
                Text('Finish day 7 for a +${CoinPolicy.streak7Bonus} week bonus', style: muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CycleStrip extends StatefulWidget {
  const _CycleStrip({required this.cycleDay, required this.todayDay});

  final int cycleDay;
  final int todayDay;

  @override
  State<_CycleStrip> createState() => _CycleStripState();
}

class _CycleStripState extends State<_CycleStrip> with SingleTickerProviderStateMixin {
  static const int _stagger = 40;
  static const int _fill = 240;
  static const int _total = 6 * _stagger + _fill;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _total),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          children: <Widget>[
            for (int day = 1; day <= 7; day++)
              Expanded(
                child: _DayCell(
                  day: day,
                  done: day <= widget.cycleDay,
                  today: day == widget.todayDay,
                  reward: CoinPolicy.streakDailyRewardForDay(day),
                  progress: Interval(
                    (day - 1) * _stagger / _total,
                    math.min(1, ((day - 1) * _stagger + _fill) / _total),
                    curve: PrismCurves.enter,
                  ).transform(_controller.value),
                  scheme: cs,
                  textTheme: theme.textTheme,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.done,
    required this.today,
    required this.reward,
    required this.progress,
    required this.scheme,
    required this.textTheme,
  });

  final int day;
  final bool done;
  final bool today;
  final int reward;
  final double progress;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final Color dim = scheme.onSurface.withValues(alpha: 0.4);
    final Color muted = scheme.onSurface.withValues(alpha: 0.6);
    final bool upcoming = !done && !today;
    final double fill = done ? progress : 0;
    return Semantics(
      label:
          'Day $day, plus $reward coins${done
              ? ', done'
              : today
              ? ', today'
              : ''}',
      excludeSemantics: true,
      child: Column(
        children: <Widget>[
          Text('Day $day', style: textTheme.labelSmall?.copyWith(fontSize: 10.5, color: upcoming ? dim : muted)),
          const SizedBox(height: 8),
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(Colors.transparent, scheme.primary, fill),
                  border: Border.all(
                    color: done || today ? scheme.primary : scheme.outlineVariant,
                    width: today ? 2 : 1.5,
                  ),
                ),
                child: done
                    ? Opacity(
                        opacity: fill,
                        child: Icon(Icons.check_rounded, size: 17, color: scheme.onPrimary),
                      )
                    : day == 7
                    ? Icon(Icons.card_giftcard_rounded, size: 16, color: today ? scheme.primary : dim)
                    : null,
              ),
              if (day == 7)
                Positioned(
                  top: -9,
                  right: -12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: scheme.tertiary.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '+${CoinPolicy.streak7Bonus}',
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        color: scheme.tertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '+$reward',
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: today ? scheme.onSurface : (upcoming ? dim : muted),
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
