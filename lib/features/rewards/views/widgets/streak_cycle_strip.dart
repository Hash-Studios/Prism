import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The 7-day streak cycle: one circle per day. Done days fill with the accent one after another. It plays again
/// when [cycleDay] changes, for example when a claim lands while the page is open.
///
/// [todayDay] marks the day to claim next. [showRewards] adds the coin reward under each day.
/// [startDelay] holds the fill back, so a sheet can land its headline first.
class StreakCycleStrip extends StatefulWidget {
  const StreakCycleStrip({
    super.key,
    required this.cycleDay,
    this.todayDay,
    this.showRewards = true,
    this.startDelay = Duration.zero,
  });

  final int cycleDay;
  final int? todayDay;
  final bool showRewards;
  final Duration startDelay;

  @override
  State<StreakCycleStrip> createState() => _StreakCycleStripState();
}

class _StreakCycleStripState extends State<StreakCycleStrip> with SingleTickerProviderStateMixin {
  late final Duration _total = widget.startDelay + PrismDurations.stagger * 6 + PrismDurations.base;
  late final AnimationController _controller = AnimationController(vsync: this, duration: _total);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _started = true;
      _controller.value = 1;
      return;
    }
    if (_started) return;
    _started = true;
    _controller.forward();
  }

  @override
  void didUpdateWidget(StreakCycleStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cycleDay != widget.cycleDay && !context.reduceMotion) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double total = _total.inMilliseconds.toDouble();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        children: <Widget>[
          for (int day = 1; day <= 7; day++)
            Expanded(
              child: _DayCell(
                day: day,
                done: day <= widget.cycleDay,
                today: day == widget.todayDay,
                showReward: widget.showRewards,
                progress: Interval(
                  (widget.startDelay.inMilliseconds + (day - 1) * PrismDurations.stagger.inMilliseconds) / total,
                  ((widget.startDelay.inMilliseconds +
                              (day - 1) * PrismDurations.stagger.inMilliseconds +
                              PrismDurations.base.inMilliseconds) /
                          total)
                      .clamp(0.0, 1.0),
                  curve: PrismCurves.enter,
                ).transform(_controller.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.done,
    required this.today,
    required this.showReward,
    required this.progress,
  });

  final int day;
  final bool done;
  final bool today;
  final bool showReward;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int reward = CoinPolicy.streakDailyRewardForDay(day);
    final double fill = done ? progress : 0;
    final TextStyle caption = PrismTextStyles.caption(context);
    final TextStyle strong = caption.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600);
    final String state = done
        ? ', done'
        : today
        ? ', today'
        : '';
    return Semantics(
      label: showReward ? 'Day $day, plus $reward coins$state' : 'Day $day$state',
      excludeSemantics: true,
      child: Column(
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Day $day',
              maxLines: 1,
              softWrap: false,
              style: (done || today ? strong : caption).copyWith(fontSize: 11),
            ),
          ),
          const SizedBox(height: PrismSpace.xs),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? Color.lerp(Colors.transparent, cs.primary, fill)
                  : today
                  ? cs.primary.withValues(alpha: 0.12)
                  : null,
              border: Border.all(color: done || today ? cs.primary : cs.outlineVariant, width: 1.5),
            ),
            child: done
                ? Opacity(
                    opacity: fill,
                    child: Icon(Icons.check_rounded, size: 17, color: cs.onPrimary),
                  )
                : day == 7
                ? Icon(Icons.card_giftcard_rounded, size: 16, color: today ? cs.primary : cs.onSurfaceVariant)
                : null,
          ),
          if (showReward) ...<Widget>[
            const SizedBox(height: PrismSpace.xs),
            Text('+$reward', style: done || today ? strong : caption.copyWith(fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
