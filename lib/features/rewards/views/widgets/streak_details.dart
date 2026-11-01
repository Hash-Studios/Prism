import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/rewards/views/widgets/streak_cycle_strip.dart';
import 'package:Prism/features/streak/data/streak_rescue_service.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

Future<void> showStreakDetails(BuildContext context, {VoidCallback? onEarnCoins}) async {
  final bool? earnCoins = await showPrismSheet<bool>(context, builder: (_) => const StreakDetails());
  if (earnCoins == true) onEarnCoins?.call();
}

class StreakDetails extends StatefulWidget {
  const StreakDetails({super.key, this.rescueService});

  final StreakRescueService? rescueService;

  @override
  State<StreakDetails> createState() => _StreakDetailsState();
}

class _StreakDetailsState extends State<StreakDetails> {
  StreakRescueService get _service => widget.rescueService ?? StreakRescueService.instance;
  StreakRescueOffer? _offer;
  bool _busy = false;
  bool _loadFailed = false;
  int? _restoredCount;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final StreakRescueOffer? offer = await _service.fetch();
      if (!mounted) return;
      setState(() {
        _offer = offer;
        _loadFailed = false;
      });
      if (offer != null) unawaited(analytics.track(StreakRescueOfferedEvent(streakCount: offer.count)));
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    if (CoinsService.instance.balanceNotifier.value < kStreakRescueCost) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _busy = true);
    final StreakRescueResult result = await _service.restore();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result.outcome) {
      case StreakRescueOutcome.restored:
        PrismHaptics.success();
        setState(() {
          _restoredCount = result.streakCount;
          _offer = null;
        });
      case StreakRescueOutcome.insufficientBalance:
        PrismHaptics.warning();
        Navigator.of(context).pop(true);
      case StreakRescueOutcome.unavailable:
        toasts.error(switch (result.reason) {
          'streak_rescue_cooldown' => context.l10n.economyStreakRescueCooldown,
          'streak_rescue_expired' => context.l10n.economyStreakRescueExpired,
          _ => context.l10n.economyStreakRescueUnavailable,
        });
        setState(() => _offer = null);
      case StreakRescueOutcome.failed:
        toasts.error(context.l10n.economyStreakRescueFailed);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<StreakStatus>(
    valueListenable: CoinsService.instance.streakNotifier,
    builder: (context, status, _) {
      final int count = _restoredCount ?? (status.active || status.claimedToday ? status.count : 0);
      final int cycleDay = _restoredCount != null
          ? (count - 1) % 7 + 1
          : (count > 0 ? status.streakDay.clamp(0, 7) : 0);
      return PrismSheetBody(
        title: context.l10n.economyDailyStreak,
        actions: <Widget>[
          PrismButton(
            label: context.l10n.actionClose,
            expand: true,
            variant: PrismButtonVariant.ghost,
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(context.l10n.economyStreakCount(count), style: PrismTextStyles.sheetHeadline(context)),
            const SizedBox(height: PrismSpace.xs),
            Text(context.l10n.economyBestStreak(status.best > count ? status.best : count)),
            const SizedBox(height: PrismSpace.lg),
            StreakCycleStrip(
              cycleDay: cycleDay,
              streakCount: count,
              todayDay: status.claimedToday ? cycleDay : (cycleDay >= 7 ? 1 : cycleDay + 1),
            ),
            if (_restoredCount != null) ...<Widget>[
              const SizedBox(height: PrismSpace.md),
              Semantics(liveRegion: true, child: Text(context.l10n.economyStreakRestoredCount(_restoredCount!))),
            ],
            if (_loadFailed) TextButton(onPressed: _load, child: Text(context.l10n.dailyMomentRetry)),
            if (_offer case final offer?) ...<Widget>[
              const SizedBox(height: PrismSpace.lg),
              Text(context.l10n.economyRestoreStreak(offer.count, kStreakRescueCost)),
              const SizedBox(height: PrismSpace.sm),
              ValueListenableBuilder<int>(
                valueListenable: CoinsService.instance.balanceNotifier,
                builder: (context, balance, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (balance < kStreakRescueCost)
                      Text(context.l10n.economyStreakRestoreShort(balance, kStreakRescueCost)),
                    PrismButton(
                      label: balance < kStreakRescueCost ? context.l10n.economyEarnCoins : context.l10n.economyRestore,
                      expand: true,
                      loading: _busy,
                      onPressed: _busy ? null : _restore,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
