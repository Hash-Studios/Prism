import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:Prism/features/daily_flow/daily_moment_presentation_gate.dart';
import 'package:Prism/features/daily_flow/data/coins_daily_moment_repository.dart';
import 'package:Prism/features/daily_flow/views/daily_moment_page.dart';
import 'package:Prism/features/rewards/views/widgets/daily_claim_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Shows the daily claim sheet when a claim lands and this route is on top.
class DailyClaimSheetHost extends StatefulWidget {
  const DailyClaimSheetHost({super.key, required this.child, required this.onSeeRewards, this.onEarnCoins});

  final Widget child;
  final VoidCallback onSeeRewards;

  /// Opens the earn section when a streak rescue needs more coins. Falls back to [onSeeRewards].
  final VoidCallback? onEarnCoins;

  @override
  State<DailyClaimSheetHost> createState() => _DailyClaimSheetHostState();
}

class _DailyClaimSheetHostState extends State<DailyClaimSheetHost> with WidgetsBindingObserver {
  final ValueNotifier<StreakClaimResult?> _notifier = CoinsService.instance.lastClaimNotifier;
  bool _scheduled = false;
  bool _presenting = false;
  Timer? _dayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifier.addListener(_schedule);
    DailyMomentPresentationGate.instance.addListener(_schedule);
    _dayTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (DailyMomentConfig.enabled) _schedule();
    });
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifier.removeListener(_schedule);
    DailyMomentPresentationGate.instance.removeListener(_schedule);
    _dayTimer?.cancel();
    super.dispose();
  }

  void _schedule() {
    if (_scheduled || _presenting || !mounted) return;
    if (!DailyMomentConfig.enabled && _notifier.value == null) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _tryShow();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _tryShow() {
    final StreakClaimResult? result = CoinsService.instance.pendingClaimForCurrentUser;
    if (!DailyMomentConfig.enabled && result == null) return;
    final bool current = ModalRoute.of(context)?.isCurrent ?? true;
    final bool resumed =
        (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) == AppLifecycleState.resumed;
    if (!current || !resumed) return;
    if (DailyMomentConfig.enabled) {
      if (!DailyMomentPresentationGate.instance.canShow) return;
      final repository = CoinsDailyMomentRepository();
      if (repository.accountId.isEmpty || repository.shownOn(repository.accountId, repository.now())) return;
      _presenting = true;
      unawaited(showDailyMoment(context, receipt: result).whenComplete(() => _presenting = false));
      return;
    }
    CoinsService.instance.consumeLastClaim();
    showDailyClaimSheet(context, result!, onSeeRewards: widget.onSeeRewards, onEarnCoins: widget.onEarnCoins);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
