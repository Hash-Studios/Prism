import 'dart:async';

import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/coins/economy_state.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:Prism/features/quests/biz/bloc/quests_bloc.j.dart';
import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:Prism/features/quests/views/widgets/chest_banner.dart';
import 'package:Prism/features/quests/views/widgets/quest_tile.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
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

  late final Timer _clock;
  List<QuestAward> _visibleAwards = const <QuestAward>[];
  String? _awardsDayKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => _onMinute());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool visible = TickerMode.valuesOf(context).enabled && (ModalRoute.of(context)?.isCurrent ?? true);
    final bool becameVisible = visible && !_visible;
    _visible = visible;
    if (becameVisible) {
      _bloc.add(const QuestsEvent.refreshed());
      _showAwards(_bloc.state);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _visible) _bloc.add(const QuestsEvent.refreshed());
  }

  void _onMinute() {
    if (!_visible) return;
    final QuestState? quests = _bloc.state.quests;
    if (quests != null && quests.dayKey != economyDayKey(DateTime.now())) _bloc.add(const QuestsEvent.refreshed());
    setState(() {});
  }

  @override
  void dispose() {
    _clock.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _bloc.close();
    super.dispose();
  }

  void _showAwards(QuestsState state) {
    if (state.awards.isEmpty) return;
    if (DailyMomentConfig.enabled) {
      if (!_visible || state.quests == null || state.quests!.dayKey != economyDayKey(DateTime.now())) return;
      _awardsDayKey = state.quests!.dayKey;
      _visibleAwards = List<QuestAward>.of(state.awards);
    } else {
      final int coins = state.awards.fold<int>(0, (int sum, QuestAward a) => sum + a.coins);
      final int xp = state.awards.fold<int>(0, (int sum, QuestAward a) => sum + a.xp);
      toasts.success(context.l10n.economyQuestDoneMessage(coins, xp));
    }
    _bloc.add(const QuestsEvent.awardsShown());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<QuestsBloc>.value(
      value: _bloc,
      child: BlocListener<QuestsBloc, QuestsState>(
        listenWhen: (before, after) => before.quests != after.quests || before.awards != after.awards,
        listener: (context, state) {
          if (state.quests == null || state.quests!.dayKey != _awardsDayKey) {
            _visibleAwards = const <QuestAward>[];
            _awardsDayKey = state.quests?.dayKey;
          }
          _showAwards(state);
        },
        child: BlocBuilder<QuestsBloc, QuestsState>(
          builder: (context, state) {
            final QuestState? quests = state.quests;
            if (quests == null || quests.dayKey != _awardsDayKey) {
              _visibleAwards = const <QuestAward>[];
              _awardsDayKey = quests?.dayKey;
            }
            if (quests == null) return const SizedBox.shrink();
            return ValueListenableBuilder<EconomyConfig>(
              valueListenable: EconomyConfig.notifier,
              builder: (context, _, _) {
                final DateTime now = DateTime.now();
                final QuestBoard? board = QuestBoard.of(
                  quests,
                  EconomyConfig.current.award,
                  today: economyDayKey(now),
                  price: CoinPolicy.dailyChestPrice,
                  l10n: context.l10n,
                );
                if (board == null) {
                  _visibleAwards = const <QuestAward>[];
                  _awardsDayKey = null;
                  return const SizedBox.shrink();
                }
                return _TodayView(board: board, now: now, onOpenSpin: widget.onOpenSpin, awards: _visibleAwards);
              },
            );
          },
        ),
      ),
    );
  }
}

class _TodayView extends StatelessWidget {
  const _TodayView({required this.board, required this.now, required this.onOpenSpin, required this.awards});

  final List<QuestAward> awards;
  final QuestBoard board;
  final DateTime now;
  final VoidCallback? onOpenSpin;

  @override
  Widget build(BuildContext context) {
    final QuestTileModel? weekly = board.weekly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (DailyMomentConfig.enabled)
          Text(context.l10n.dailyMomentQuests, style: PrismTextStyles.sectionTitle(context))
        else
          _Header(untilReset: nextDailyReset(now).difference(now)),
        if (DailyMomentConfig.enabled)
          for (final QuestAward award in awards)
            Padding(
              padding: const EdgeInsets.only(top: PrismSpace.xs),
              child: Text(
                context.l10n.economyQuestDoneMessage(award.coins, award.xp),
                style: PrismTextStyles.caption(context),
              ),
            ),
        const SizedBox(height: PrismSpace.sm),
        for (final QuestTileModel tile in board.daily) ...<Widget>[
          QuestTile(key: ValueKey<String>(tile.id), quest: tile),
          const SizedBox(height: PrismSpace.sm),
        ],
        if (!DailyMomentConfig.enabled) ChestBanner(board: board, onOpenSpin: onOpenSpin),
        if (weekly != null) ...<Widget>[
          const SizedBox(height: PrismSpace.md),
          QuestTile(
            key: ValueKey<String>(weekly.id),
            quest: weekly,
            endsIn: DailyMomentConfig.enabled
                ? null
                : formatCountdown(context.l10n, nextWeeklyReset(now).difference(now)),
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
          child: Semantics(
            header: true,
            child: Text(context.l10n.economyDailyQuests, style: PrismTextStyles.sectionTitle(context)),
          ),
        ),
        const SizedBox(width: PrismSpace.sm),
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.5,
          child: DecoratedBox(
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
                    context.l10n.economyQuestNewIn(formatCountdown(context.l10n, untilReset)),
                    style: PrismTextStyles.caption(context).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
