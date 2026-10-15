import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/rewards/views/widgets/streak_cycle_strip.dart';
import 'package:Prism/features/streak/data/streak_rescue_service.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

const double _kSmallScreenHeight = 700;

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
  // Glint lands, the reward counts up, then the week fills in: about a second in all.
  static final Duration _total = PrismDurations.slow * 3;
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
    PrismHaptics.tap();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    if (_restoring) return;
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
    final bool offerOpen = _offer != null && _restoredCount == null;
    final PrismButton seeRewards = PrismButton(
      label: r.streakBroken ? 'Get a freeze for next time' : 'See rewards',
      expand: true,
      variant: r.streakBroken && !offerOpen ? PrismButtonVariant.primary : PrismButtonVariant.ghost,
      onPressed: _restoring ? null : () => Navigator.of(context).pop(_ClaimSheetExit.seeRewards),
    );
    final PrismButton done = PrismButton(
      label: _restoredCount != null || !r.streakBroken ? 'Nice' : 'OK',
      expand: true,
      variant: offerOpen
          ? PrismButtonVariant.tonal
          : r.streakBroken
          ? PrismButtonVariant.ghost
          : PrismButtonVariant.primary,
      onPressed: _restoring ? null : () => Navigator.of(context).pop(_ClaimSheetExit.dismissed),
    );
    return PrismSheetBody(
      centered: true,
      scrollable: true,
      actions: <Widget>[
        if (r.streakBroken && !offerOpen) ...<Widget>[seeRewards, done] else ...<Widget>[done, seeRewards],
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
          if (offerOpen) ...<Widget>[
            const SizedBox(height: PrismSpace.md),
            _RescueCard(offer: _offer!, busy: _restoring, onRestore: _restore),
          ],
        ],
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
    return ValueListenableBuilder<int>(
      valueListenable: CoinsService.instance.balanceNotifier,
      builder: (context, balance, _) {
        final bool short = balance < kStreakRescueCost;
        return PrismCard(
          padding: const EdgeInsets.all(PrismSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Restore your ${offer.count}-day streak · $kStreakRescueCost coins',
                      style: PrismTextStyles.rowTitle(context),
                    ),
                  ),
                  const SizedBox(width: PrismSpace.xs),
                  const PrismCoinIcon(size: 18),
                ],
              ),
              if (short) ...<Widget>[
                const SizedBox(height: PrismSpace.xxs),
                Text('You have $balance. You need $kStreakRescueCost.', style: PrismTextStyles.caption(context)),
              ],
              const SizedBox(height: PrismSpace.sm),
              PrismButton(
                label: short ? 'Earn coins' : 'Restore',
                expand: true,
                loading: busy,
                size: PrismButtonSize.compact,
                onPressed: busy ? null : onRestore,
              ),
            ],
          ),
        );
      },
    );
  }
}
