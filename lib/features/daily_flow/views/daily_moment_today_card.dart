import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/daily_flow/data/coins_daily_moment_repository.dart';
import 'package:Prism/features/daily_flow/views/daily_moment_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

class DailyMomentTodayCard extends StatefulWidget {
  const DailyMomentTodayCard({super.key});

  @override
  State<DailyMomentTodayCard> createState() => _DailyMomentTodayCardState();
}

class _DailyMomentTodayCardState extends State<DailyMomentTodayCard> with WidgetsBindingObserver {
  Timer? _dayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dayTimer = Timer.periodic(const Duration(minutes: 1), (_) => _refreshDay());
  }

  void _refreshDay() {
    CoinsService.instance.refreshSpinWheelStatus();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDay();
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CoinsService coins = CoinsService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        coins.balanceNotifier,
        coins.questsNotifier,
        coins.spinWheelNotifier,
        coins.lastClaimNotifier,
        coins.streakNotifier,
      ]),
      builder: (context, _) {
        final repository = CoinsDailyMomentRepository();
        final bool streak = repository.pendingReceipt != null || repository.streakAvailable;
        final bool chest = repository.chest?.opened == false;
        final bool spin = coins.spinWheelNotifier.value.freeSpinAvailable;
        final bool complete = !streak && !chest && !spin && repository.chest != null;
        return PrismCard(
          padding: const EdgeInsets.all(PrismSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: Text(context.l10n.dailyMomentToday, style: PrismTextStyles.sectionTitle(context))),
                  const Glint(size: 56),
                ],
              ),
              const SizedBox(height: PrismSpace.sm),
              Text(
                complete ? context.l10n.dailyMomentComplete : context.l10n.dailyMomentReady,
                style: PrismTextStyles.cardTitle(context),
              ),
              const SizedBox(height: PrismSpace.xs),
              Text(context.l10n.dailyMomentBalance(repository.balance), style: PrismTextStyles.body(context)),
              if (streak) Text(context.l10n.dailyMomentStreakLeft, style: PrismTextStyles.caption(context)),
              if (chest) Text(context.l10n.dailyMomentChestLeft, style: PrismTextStyles.caption(context)),
              if (spin) Text(context.l10n.dailyMomentSpinLeft, style: PrismTextStyles.caption(context)),
              if (!complete) ...<Widget>[
                const SizedBox(height: PrismSpace.md),
                PrismButton(
                  label: context.l10n.dailyMomentResume,
                  onPressed: () => unawaited(showDailyMoment(context)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
