import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Shows the sheet for one paid daily claim. [onSeeRewards] runs after the sheet closes.
Future<void> showDailyClaimSheet(BuildContext context, StreakClaimResult result, {VoidCallback? onSeeRewards}) async {
  final bool? seeRewards = await showPrismSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => DailyClaimSheet(result: result),
  );
  if (seeRewards == true) onSeeRewards?.call();
}

class DailyClaimSheet extends StatefulWidget {
  const DailyClaimSheet({super.key, required this.result});

  final StreakClaimResult result;

  @override
  State<DailyClaimSheet> createState() => _DailyClaimSheetState();
}

class _DailyClaimSheetState extends State<DailyClaimSheet> with SingleTickerProviderStateMixin {
  static const Duration _total = Duration(milliseconds: 1500);
  late final AnimationController _c = AnimationController(vsync: this, duration: _total);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _started = true;
      _c.value = 1;
      return;
    }
    if (_started) return;
    _started = true;
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  GlintMood get _mood {
    final StreakClaimResult r = widget.result;
    if (r.streakBroken) return GlintMood.sad;
    if (r.freezesUsed > 0) return GlintMood.proud;
    if (r.milestone != null || r.isWeekComplete) return GlintMood.celebrate;
    return GlintMood.happy;
  }

  ({String title, String? sub, bool showReward}) get _copy {
    final StreakClaimResult r = widget.result;
    if (r.streakBroken) {
      return (
        title: 'Your streak reset',
        sub: 'You were on ${r.previousStreakCount} days. Start again today, +${r.totalReward} coins.',
        showReward: false,
      );
    }
    if (r.freezesUsed > 0) {
      return (
        title: 'A freeze saved your ${r.streakCount}-day streak',
        sub: '${r.freezesLeft} ${r.freezesLeft == 1 ? 'freeze' : 'freezes'} left',
        showReward: true,
      );
    }
    if (r.milestone != null) return (title: '${r.milestone}-day streak!', sub: null, showReward: true);
    if (r.isWeekComplete) {
      return (title: 'Week complete!', sub: 'Day ${r.streakCount} of your streak', showReward: true);
    }
    return (title: 'Day ${r.streakCount}', sub: null, showReward: true);
  }

  String? get _breakdown {
    final StreakClaimResult r = widget.result;
    final List<String> parts = <String>[
      '+${r.dailyReward} today',
      if (r.streakBonusReward > 0) '+${r.streakBonusReward} week bonus',
      if (r.proBonusReward > 0) '+${r.proBonusReward} Pro bonus',
    ];
    return parts.length > 1 ? parts.join(' · ') : null;
  }

  @override
  Widget build(BuildContext context) {
    final StreakClaimResult r = widget.result;
    final bool small = MediaQuery.sizeOf(context).height < 700;
    final copy = _copy;
    final String? breakdown = _breakdown;
    final Widget glint = AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final double t = const Interval(0.05, 0.4, curve: PrismCurves.pop).transform(_c.value);
        return Transform.scale(scale: t.clamp(0.0, 1.2), child: child);
      },
      child: Glint(mood: _mood, size: small ? 88 : 140),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            glint,
            const SizedBox(height: 8),
            Text(copy.title, textAlign: TextAlign.center, style: PrismTextStyles.sheetHeadline(context)),
            if (copy.sub != null) ...[
              const SizedBox(height: 4),
              Text(copy.sub!, textAlign: TextAlign.center, style: PrismTextStyles.body(context)),
            ],
            if (copy.showReward) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const PrismCoinIcon(size: 32),
                  const SizedBox(width: 10),
                  AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      final double t = const Interval(0.1, 0.6, curve: Curves.easeOutCubic).transform(_c.value);
                      return Text('+${(r.totalReward * t).round()}', style: PrismTextStyles.numeral(context, 44));
                    },
                  ),
                ],
              ),
              if (breakdown != null) ...[
                const SizedBox(height: 8),
                Text(breakdown, style: PrismTextStyles.caption(context)),
              ],
            ],
            const SizedBox(height: 24),
            _CycleStrip(day: r.streakDay, animation: _c),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                  textStyle: PrismTextStyles.rowTitle(context),
                ),
                child: Text(r.streakBroken ? 'OK' : 'Nice'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                r.streakBroken ? 'Get a freeze for next time' : 'See rewards',
                style: PrismTextStyles.rowTitle(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CycleStrip extends StatelessWidget {
  const _CycleStrip({required this.day, required this.animation});

  final int day;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (int i = 1; i <= 7; i++)
          Expanded(
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    final double start = 0.5 + (i - 1) * 0.04;
                    final double t = Interval(
                      start,
                      (start + 0.2).clamp(0.0, 1.0),
                      curve: PrismCurves.enter,
                    ).transform(animation.value);
                    final bool done = i <= day;
                    return Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? Color.lerp(Colors.transparent, scheme.primary, t) : null,
                        border: done && t >= 1
                            ? null
                            : Border.all(color: scheme.onSurface.withValues(alpha: 0.12), width: 1.5),
                      ),
                      child: done && t > 0
                          ? Opacity(
                              opacity: t,
                              child: Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary),
                            )
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text('Day $i', style: PrismTextStyles.caption(context).copyWith(fontSize: 10)),
              ],
            ),
          ),
      ],
    );
  }
}
