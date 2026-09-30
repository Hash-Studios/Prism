import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/features/rewards/views/widgets/daily_claim_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Shows the daily claim sheet when a claim lands and this route is on top.
class DailyClaimSheetHost extends StatefulWidget {
  const DailyClaimSheetHost({super.key, required this.child, required this.onSeeRewards});

  final Widget child;
  final VoidCallback onSeeRewards;

  @override
  State<DailyClaimSheetHost> createState() => _DailyClaimSheetHostState();
}

class _DailyClaimSheetHostState extends State<DailyClaimSheetHost> with WidgetsBindingObserver {
  final ValueNotifier<StreakClaimResult?> _notifier = CoinsService.instance.lastClaimNotifier;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifier.addListener(_schedule);
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
    super.dispose();
  }

  void _schedule() {
    if (_scheduled || _notifier.value == null || !mounted) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _tryShow();
    });
  }

  void _tryShow() {
    final StreakClaimResult? result = CoinsService.instance.pendingClaimForCurrentUser;
    if (result == null) return;
    final bool current = ModalRoute.of(context)?.isCurrent ?? true;
    final bool resumed =
        (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) == AppLifecycleState.resumed;
    if (!current || !resumed) return;
    CoinsService.instance.consumeLastClaim();
    showDailyClaimSheet(context, result, onSeeRewards: widget.onSeeRewards);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
