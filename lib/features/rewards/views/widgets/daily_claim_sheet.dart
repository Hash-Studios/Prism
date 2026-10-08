import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/streak/data/streak_rescue_service.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

enum _ClaimSheetExit { dismissed, seeRewards, earnCoins }

/// Shows the sheet for one paid daily claim. [onSeeRewards] runs after the sheet closes.
/// [onEarnCoins] runs when the user has too few coins for a streak rescue. It falls back to [onSeeRewards].
Future<void> showDailyClaimSheet(
  BuildContext context,
  StreakClaimResult result, {
  VoidCallback? onSeeRewards,
  VoidCallback? onEarnCoins,
  StreakRescueService? rescueService,
}) async {
  final _ClaimSheetExit? exit = await showPrismSheet<_ClaimSheetExit>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => DailyClaimSheet(result: result, rescueService: rescueService),
  );
  switch (exit) {
    case _ClaimSheetExit.seeRewards:
      onSeeRewards?.call();
    case _ClaimSheetExit.earnCoins:
      (onEarnCoins ?? onSeeRewards)?.call();
    case _ClaimSheetExit.dismissed:
    case null:
      break;
  }
}

class DailyClaimSheet extends StatefulWidget {
  const DailyClaimSheet({super.key, required this.result, this.rescueService});

  final StreakClaimResult result;

  /// Test hook. The app uses [StreakRescueService.instance].
  final StreakRescueService? rescueService;

  @override
  State<DailyClaimSheet> createState() => _DailyClaimSheetState();
}

class _DailyClaimSheetState extends State<DailyClaimSheet> with SingleTickerProviderStateMixin {
  static const Duration _total = Duration(milliseconds: 1500);
  late final AnimationController _c = AnimationController(vsync: this, duration: _total);
  bool _started = false;
  late StreakRescueOffer? _offer = StreakRescueOffer.fromClaim(widget.result);
  bool _restoring = false;
  int? _restoredCount;

  StreakRescueService get _rescue => widget.rescueService ?? StreakRescueService.instance;

  @override
  void initState() {
    super.initState();
    final StreakRescueOffer? offer = _offer;
    if (offer != null) analytics.track(StreakRescueOfferedEvent(streakCount: offer.count));
  }

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

  Future<void> _restore() async {
    if (_restoring) return;
    PrismHaptics.tap();
    if (CoinsService.instance.balanceNotifier.value < kStreakRescueCost) {
      Navigator.of(context).pop(_ClaimSheetExit.earnCoins);
      return;
    }
    setState(() => _restoring = true);
    final StreakRescueResult result = await _rescue.restore();
    if (!mounted) return;
    switch (result.outcome) {
      case StreakRescueOutcome.restored:
        PrismHaptics.success();
        setState(() {
          _restoring = false;
          _restoredCount = result.streakCount > 0 ? result.streakCount : (_offer?.count ?? 0) + 1;
        });
        return;
      case StreakRescueOutcome.insufficientBalance:
        PrismHaptics.warning();
        setState(() => _restoring = false);
        Navigator.of(context).pop(_ClaimSheetExit.earnCoins);
        return;
      case StreakRescueOutcome.unavailable:
        toasts.error(switch (result.reason) {
          'streak_rescue_cooldown' => 'You can restore one streak every 30 days.',
          'streak_rescue_expired' => 'The 48 hours to restore this streak are over.',
          _ => "This streak can't be restored now.",
        });
        setState(() {
          _restoring = false;
          _offer = null;
        });
      case StreakRescueOutcome.failed:
        toasts.error("Couldn't restore your streak. Try again.");
        setState(() => _restoring = false);
    }
  }

  GlintMood get _mood {
    final StreakClaimResult r = widget.result;
    if (_restoredCount != null) return GlintMood.celebrate;
    if (r.streakBroken) return GlintMood.sad;
    if (r.freezesUsed > 0) return GlintMood.proud;
    if (r.milestone != null || r.isWeekComplete) return GlintMood.celebrate;
    return GlintMood.happy;
  }

  ({String title, String? sub, bool showReward}) get _copy {
    final StreakClaimResult r = widget.result;
    final int? restored = _restoredCount;
    if (restored != null) {
      return (title: 'Your streak is back', sub: 'You are on $restored days again.', showReward: false);
    }
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
            if (_offer != null && _restoredCount == null) ...[
              _RescueCard(offer: _offer!, busy: _restoring, onRestore: _restore),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: _offer != null && _restoredCount == null
                  ? FilledButton.tonal(
                      onPressed: _restoring ? null : () => Navigator.of(context).pop(_ClaimSheetExit.dismissed),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: const StadiumBorder(),
                        textStyle: PrismTextStyles.rowTitle(context),
                      ),
                      child: const Text('OK'),
                    )
                  : FilledButton(
                      onPressed: () => Navigator.of(context).pop(_ClaimSheetExit.dismissed),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: const StadiumBorder(),
                        textStyle: PrismTextStyles.rowTitle(context),
                      ),
                      child: Text(_restoredCount != null || !r.streakBroken ? 'Nice' : 'OK'),
                    ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _restoring ? null : () => Navigator.of(context).pop(_ClaimSheetExit.seeRewards),
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

class _RescueCard extends StatelessWidget {
  const _RescueCard({required this.offer, required this.busy, required this.onRestore});

  final StreakRescueOffer offer;
  final bool busy;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<int>(
      valueListenable: CoinsService.instance.balanceNotifier,
      builder: (context, balance, _) {
        final bool short = balance < kStreakRescueCost;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Restore your ${offer.count}-day streak · $kStreakRescueCost coins',
                        style: PrismTextStyles.rowTitle(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const PrismCoinIcon(size: 18),
                  ],
                ),
                if (short) ...[
                  const SizedBox(height: 4),
                  Text('You have $balance. You need $kStreakRescueCost.', style: PrismTextStyles.caption(context)),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: busy ? null : onRestore,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                    textStyle: PrismTextStyles.rowTitle(context),
                  ),
                  child: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(short ? 'Earn coins' : 'Restore'),
                ),
              ],
            ),
          ),
        );
      },
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
