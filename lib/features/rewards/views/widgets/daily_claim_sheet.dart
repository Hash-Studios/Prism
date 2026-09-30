import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/rewards/views/widgets/streak_cycle_strip.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double _kSmallScreenHeight = 700;

/// Shows the sheet for one paid daily claim. [onSeeRewards] runs after the sheet closes.
Future<void> showDailyClaimSheet(BuildContext context, StreakClaimResult result, {VoidCallback? onSeeRewards}) async {
  final bool? seeRewards = await showPrismSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
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
  // Glint lands, the reward counts up, then the week fills in: about a second in all.
  static final Duration _total = PrismDurations.slow * 3;
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
    HapticFeedback.lightImpact();
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
    final bool small = MediaQuery.sizeOf(context).height < _kSmallScreenHeight;
    final ({String title, String? sub, bool showReward}) copy = _copy;
    final String? breakdown = _breakdown;
    final Widget glint = AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final double t = const Interval(0.05, 0.4, curve: PrismCurves.pop).transform(_c.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
        );
      },
      child: Glint(mood: _mood, size: small ? 88 : 128),
    );
    final PrismButton seeRewards = PrismButton(
      label: r.streakBroken ? 'Get a freeze for next time' : 'See rewards',
      expand: true,
      variant: r.streakBroken ? PrismButtonVariant.primary : PrismButtonVariant.ghost,
      onPressed: () => Navigator.of(context).pop(true),
    );
    final PrismButton done = PrismButton(
      label: r.streakBroken ? 'OK' : 'Nice',
      expand: true,
      variant: r.streakBroken ? PrismButtonVariant.ghost : PrismButtonVariant.primary,
      onPressed: () => Navigator.of(context).pop(false),
    );
    return PrismSheetBody(
      centered: true,
      scrollable: true,
      actions: <Widget>[
        if (r.streakBroken) ...<Widget>[seeRewards, done] else ...<Widget>[done, seeRewards],
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          glint,
          const SizedBox(height: PrismSpace.xs),
          Semantics(
            header: true,
            child: Text(copy.title, textAlign: TextAlign.center, style: PrismTextStyles.sheetHeadline(context)),
          ),
          if (copy.sub != null) ...<Widget>[
            const SizedBox(height: PrismSpace.xxs),
            Text(copy.sub!, textAlign: TextAlign.center, style: PrismTextStyles.body(context)),
          ],
          if (copy.showReward) ...<Widget>[
            const SizedBox(height: PrismSpace.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const PrismCoinIcon(size: 32),
                const SizedBox(width: PrismSpace.sm),
                AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final double t = const Interval(0.1, 0.6, curve: PrismCurves.enter).transform(_c.value);
                    return Text('+${(r.totalReward * t).round()}', style: PrismTextStyles.numeral(context, 44));
                  },
                ),
              ],
            ),
            if (breakdown != null) ...<Widget>[
              const SizedBox(height: PrismSpace.xs),
              Text(breakdown, textAlign: TextAlign.center, style: PrismTextStyles.caption(context)),
            ],
          ],
          const SizedBox(height: PrismSpace.xl),
          StreakCycleStrip(
            cycleDay: r.streakDay,
            showRewards: false,
            startDelay: PrismDurations.slow + PrismDurations.fast,
          ),
        ],
      ),
    );
  }
}
