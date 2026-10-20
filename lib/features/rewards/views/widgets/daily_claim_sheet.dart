import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/rewards/views/widgets/streak_cycle_strip.dart';
import 'package:Prism/features/streak/data/streak_rescue_service.dart';
import 'package:Prism/l10n/l10n.dart';
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
    context,
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
          'streak_rescue_cooldown' => context.l10n.economyStreakRescueCooldown,
          'streak_rescue_expired' => context.l10n.economyStreakRescueExpired,
          _ => context.l10n.economyStreakRescueUnavailable,
        });
        setState(() {
          _restoring = false;
          _offer = null;
        });
      case StreakRescueOutcome.failed:
        toasts.error(context.l10n.economyStreakRescueFailed);
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

  ({String title, String? sub, bool showReward}) _copy(AppLocalizations l10n) {
    final StreakClaimResult r = widget.result;
    final int? restored = _restoredCount;
    if (restored != null) {
      return (title: l10n.economyStreakRestored, sub: l10n.economyStreakRestoredCount(restored), showReward: false);
    }
    if (r.streakBroken) {
      return (
        title: l10n.economyStreakReset,
        sub: l10n.economyStreakResetMessage(r.previousStreakCount, r.totalReward),
        showReward: false,
      );
    }
    if (r.freezesUsed > 0) {
      return (
        title: l10n.economyStreakFreezeSaved(r.streakCount),
        sub: l10n.economyStreakFreezesLeft(r.freezesLeft),
        showReward: true,
      );
    }
    final bool chest = r.isChest;
    if (r.milestone != null) {
      return (
        title: l10n.economyDayStreakMilestone(r.milestone!),
        sub: chest ? l10n.economyDay7Chest : null,
        showReward: true,
      );
    }
    if (r.isWeekComplete) {
      return (
        title: chest ? l10n.economyDay7Chest : l10n.economyWeekComplete,
        sub: l10n.economyStreakDayNumber(r.streakCount),
        showReward: true,
      );
    }
    return (title: l10n.economyDayLabel(r.streakCount), sub: null, showReward: true);
  }

  String? _breakdown(AppLocalizations l10n) {
    final StreakClaimResult r = widget.result;
    final List<String> parts = <String>[
      l10n.economyStreakDailyReward(r.dailyReward),
      if (r.streakBonusReward > 0) l10n.economyStreakChestReward(r.streakBonusReward),
      if (r.proBonusReward > 0)
        l10n.economyStreakProReward(r.proBonusReward, EconomyConfig.current.award.proStreakMultiplier.toString()),
    ];
    return parts.length > 1 ? parts.join(' · ') : null;
  }

  @override
  Widget build(BuildContext context) {
    final StreakClaimResult r = widget.result;
    final bool small = MediaQuery.sizeOf(context).height < _kSmallScreenHeight;
    final ({String title, String? sub, bool showReward}) copy = _copy(context.l10n);
    final String? breakdown = _breakdown(context.l10n);
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
      label: r.streakBroken ? context.l10n.economyGetFreezeNextTime : context.l10n.economySeeRewards,
      expand: true,
      variant: r.streakBroken && !offerOpen ? PrismButtonVariant.primary : PrismButtonVariant.ghost,
      onPressed: _restoring ? null : () => Navigator.of(context).pop(_ClaimSheetExit.seeRewards),
    );
    final PrismButton done = PrismButton(
      label: _restoredCount != null || !r.streakBroken ? context.l10n.economyNice : context.l10n.actionDone,
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
                    return Text(
                      '+${formatLocalizedNumber((r.totalReward * t).round(), context.l10n)}',
                      style: PrismTextStyles.numeral(context, 44),
                    );
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
            streakCount: r.streakCount,
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
                      context.l10n.economyRestoreStreak(offer.count, kStreakRescueCost),
                      style: PrismTextStyles.rowTitle(context),
                    ),
                  ),
                  const SizedBox(width: PrismSpace.xs),
                  const PrismCoinIcon(size: 18),
                ],
              ),
              if (short) ...<Widget>[
                const SizedBox(height: PrismSpace.xxs),
                Text(
                  context.l10n.economyStreakRestoreShort(balance, kStreakRescueCost),
                  style: PrismTextStyles.caption(context),
                ),
              ],
              const SizedBox(height: PrismSpace.sm),
              PrismButton(
                label: short ? context.l10n.economyEarnCoins : context.l10n.economyRestore,
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
