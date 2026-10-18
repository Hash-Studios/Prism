import 'dart:async';

import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/coins/economy_state.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/quests/biz/bloc/quests_bloc.j.dart';
import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:Prism/features/quests/views/widgets/chest_banner.dart';
import 'package:Prism/features/quests/views/widgets/chest_sheet.dart';
import 'package:Prism/features/quests/views/widgets/quest_tile.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Today's quests: three daily tiles, the chest with its booster and the weekly quest.
/// [onOpenSpin] opens the spin machine. Pro users tap it from the booster strip.
class TodayCard extends StatefulWidget {
  const TodayCard({super.key, this.onOpenSpin});

  final VoidCallback? onOpenSpin;

  @override
  State<TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<TodayCard> with WidgetsBindingObserver {
  late final QuestsBloc _bloc = getIt<QuestsBloc>()..add(const QuestsEvent.started());

  /// The Rewards tab stays built under other tabs and pushed routes.
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool visible = TickerMode.valuesOf(context).enabled && (ModalRoute.of(context)?.isCurrent ?? true);
    if (visible && !_visible) _bloc.add(const QuestsEvent.refreshed());
    _visible = visible;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _visible) _bloc.add(const QuestsEvent.refreshed());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<QuestsBloc>.value(
      value: _bloc,
      child: MultiBlocListener(
        listeners: <BlocListener<QuestsBloc, QuestsState>>[
          BlocListener<QuestsBloc, QuestsState>(
            listenWhen: (before, after) => after.awards.isNotEmpty && before.awards != after.awards,
            listener: (context, state) {
              final int coins = state.awards.fold<int>(0, (int sum, QuestAward a) => sum + a.coins);
              final int xp = state.awards.fold<int>(0, (int sum, QuestAward a) => sum + a.xp);
              final String reward = <String>[if (coins > 0) '+$coins coins', if (xp > 0) '+$xp XP'].join(' · ');
              toasts.success(reward.isEmpty ? 'Quest done' : 'Quest done: $reward');
              context.read<QuestsBloc>().add(const QuestsEvent.awardsShown());
            },
          ),
          BlocListener<QuestsBloc, QuestsState>(
            listenWhen: (before, after) => after.chest != null && before.chest != after.chest,
            listener: _onChest,
          ),
        ],
        child: BlocBuilder<QuestsBloc, QuestsState>(
          builder: (context, state) {
            final QuestState? quests = state.quests;
            if (quests == null) return const SizedBox.shrink();
            return ValueListenableBuilder<EconomyConfig>(
              valueListenable: EconomyConfig.notifier,
              builder: (context, _, _) => _MinuteClock(
                builder: (context, now) => _TodayView(
                  board: QuestBoard.of(quests, EconomyConfig.current.award),
                  now: now,
                  opening: state.opening,
                  onOpenSpin: widget.onOpenSpin,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _onChest(BuildContext context, QuestsState state) async {
    final ChestResult chest = state.chest!;
    switch (chest.outcome) {
      case ChestOutcome.opened:
        final bool openShop = await showChestSheet(context, chest);
        if (openShop && context.mounted) await context.router.root.push(const ShopRoute());
      case ChestOutcome.locked:
        toasts.info('Finish your 3 quests to open the chest.');
      case ChestOutcome.alreadyOpened:
        break;
      case ChestOutcome.failed:
        toasts.error("Couldn't open the chest. Try again.");
    }
  }
}

class _MinuteClock extends StatefulWidget {
  const _MinuteClock({required this.builder});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<_MinuteClock> createState() => _MinuteClockState();
}

class _MinuteClockState extends State<_MinuteClock> {
  late final Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}

class _TodayView extends StatelessWidget {
  const _TodayView({required this.board, required this.now, required this.opening, required this.onOpenSpin});

  final QuestBoard board;
  final DateTime now;
  final bool opening;
  final VoidCallback? onOpenSpin;

  @override
  Widget build(BuildContext context) {
    final QuestTileModel? weekly = board.weekly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(untilReset: nextDailyReset(now).difference(now)),
        const SizedBox(height: PrismSpace.sm),
        for (final QuestTileModel tile in board.daily) ...<Widget>[
          QuestTile(key: ValueKey<String>(tile.id), quest: tile),
          const SizedBox(height: PrismSpace.sm),
        ],
        ChestBanner(board: board, opening: opening, onOpenSpin: onOpenSpin),
        if (weekly != null) ...<Widget>[
          const SizedBox(height: PrismSpace.md),
          QuestTile(
            key: ValueKey<String>(weekly.id),
            quest: weekly,
            endsIn: formatCountdown(nextWeeklyReset(now).difference(now)),
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.untilReset});

  final Duration untilReset;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(header: true, child: Text('Daily quests', style: PrismTextStyles.sectionTitle(context))),
        ),
        const SizedBox(width: PrismSpace.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(PrismRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm, vertical: PrismSpace.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.schedule_rounded, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: PrismSpace.xxs),
                Text(
                  'New in ${formatCountdown(untilReset)}',
                  style: PrismTextStyles.caption(context).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
