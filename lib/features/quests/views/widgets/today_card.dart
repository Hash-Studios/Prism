import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/quests/biz/bloc/quests_bloc.j.dart';
import 'package:Prism/features/quests/domain/quest_catalog.dart';
import 'package:Prism/features/quests/views/widgets/chest_sheet.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Today's quests: three daily items, the bonus item, the chest and the weekly quest.
/// [onOpenProSpin] scrolls to the Pro spin card. Pro users tap it from the bonus row.
class TodayCard extends StatelessWidget {
  const TodayCard({super.key, this.onOpenProSpin});

  final VoidCallback? onOpenProSpin;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<QuestsBloc>(
      create: (_) => getIt<QuestsBloc>()..add(const QuestsEvent.started()),
      child: MultiBlocListener(
        listeners: <BlocListener<QuestsBloc, QuestsState>>[
          BlocListener<QuestsBloc, QuestsState>(
            listenWhen: (before, after) => after.awards.isNotEmpty && before.awards != after.awards,
            listener: (context, state) {
              final int coins = state.awards.fold<int>(0, (int sum, QuestAward a) => sum + a.coins);
              toasts.success(coins > 0 ? 'Quest done: +$coins coins' : 'Quest done');
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
            return _TodayView(quests: quests, opening: state.opening, onOpenProSpin: onOpenProSpin);
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

class _TodayView extends StatelessWidget {
  const _TodayView({required this.quests, required this.opening, required this.onOpenProSpin});

  final QuestState quests;
  final bool opening;
  final VoidCallback? onOpenProSpin;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int done = quests.items.where((QuestItem q) => q.claimed).length;
    final QuestItem? bonus = quests.bonus;
    final QuestItem? weekly = quests.weekly;
    final Widget divider = Padding(
      padding: const EdgeInsets.symmetric(vertical: PrismSpace.xs),
      child: Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
    );
    return PrismCard(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: PrismSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(PrismSpace.xxs, PrismSpace.xxs, PrismSpace.xxs, PrismSpace.xs),
            child: Row(
              children: <Widget>[
                Expanded(child: Text('Today', style: PrismTextStyles.cardTitle(context))),
                Text('$done of ${quests.items.length} done', style: PrismTextStyles.caption(context)),
              ],
            ),
          ),
          for (final QuestItem item in quests.items) _QuestRow(item: item, reward: '+${CoinPolicy.questCoins}'),
          if (bonus != null) ...<Widget>[divider, _BonusRow(item: bonus, onOpenProSpin: onOpenProSpin)],
          divider,
          _ChestRow(quests: quests, done: done, opening: opening),
          if (weekly != null) ...<Widget>[
            divider,
            _QuestRow(item: weekly, reward: '+${EconomyConfig.current.award.weeklyQuestCoins}', weekly: true),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.icon,
    required this.title,
    required this.semanticLabel,
    this.subtitle,
    this.progress,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String semanticLabel;
  final String? subtitle;

  /// 0..1. Draws a thin bar under the title.
  final double? progress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PrismSpace.xs),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(PrismRadius.xs + 2),
                ),
                child: Icon(icon, size: 18, color: cs.onSurface),
              ),
              const SizedBox(width: PrismSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(title, style: PrismTextStyles.rowTitle(context)),
                    if (subtitle != null) Text(subtitle!, style: PrismTextStyles.caption(context)),
                    if (progress != null) ...<Widget>[
                      const SizedBox(height: PrismSpace.xs),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: progress),
                        duration: context.motion(PrismDurations.base),
                        curve: PrismCurves.enter,
                        builder: (context, value, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(PrismRadius.pill),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 3,
                            color: cs.primary,
                            backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[const SizedBox(width: PrismSpace.sm), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class _Reward extends StatelessWidget {
  const _Reward(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const PrismCoinIcon(size: 14),
        const SizedBox(width: 5),
        Text(label, style: PrismTextStyles.rowTitle(context).copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done();

  @override
  Widget build(BuildContext context) => const Icon(Icons.check_rounded, size: 22, color: PrismColors.success);
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({required this.item, required this.reward, this.weekly = false});

  final QuestItem item;
  final String reward;
  final bool weekly;

  @override
  Widget build(BuildContext context) {
    final QuestInfo info = questInfo(item.id);
    final bool done = item.claimed;
    final String count = '${item.progress} of ${item.target}';
    return _ItemRow(
      icon: info.icon,
      title: info.title,
      subtitle: weekly ? 'This week · $count' : (item.target > 1 && !done ? count : null),
      semanticLabel: done ? '${info.title}, done' : '${info.title}, $count',
      progress: done ? 1 : item.progress / item.target,
      trailing: done ? const _Done() : _Reward(reward),
    );
  }
}

class _BonusRow extends StatefulWidget {
  const _BonusRow({required this.item, required this.onOpenProSpin});

  final QuestItem item;
  final VoidCallback? onOpenProSpin;

  @override
  State<_BonusRow> createState() => _BonusRowState();
}

class _BonusRowState extends State<_BonusRow> {
  bool _loading = false;

  Future<void> _watchAd() async {
    if (_loading) return;
    final int reward = CoinsService.instance.adsRewardNow;
    setState(() => _loading = true);
    final QuestsBloc bloc = context.read<QuestsBloc>();
    final bool credited = await CoinGate.forContext(context).watchAdForCoins(
      sourceTag: 'quests.bonus.rewarded_ad',
      upsellSource: 'quests_bonus_ad',
      isMounted: () => mounted,
      adErrorMessage: 'Ad was not completed.',
    );
    if (credited) {
      toasts.success('+$reward coins');
      bloc.add(const QuestsEvent.refreshed());
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final QuestItem item = widget.item;
    final bool pro = item.id == 'pro_spin';
    final QuestInfo info = questInfo(item.id);
    final String title = item.claimed ? info.title : (pro ? info.title : watchAdOptionLabel());
    return _ItemRow(
      icon: info.icon,
      title: title,
      subtitle: 'Doubles your chest',
      semanticLabel: item.claimed ? '${info.title}, done. Doubles your chest' : '$title. Doubles your chest',
      trailing: item.claimed
          ? const _Done()
          : PrismButton(
              label: pro ? 'Spin' : 'Watch',
              variant: PrismButtonVariant.tonal,
              size: PrismButtonSize.compact,
              loading: _loading,
              onPressed: pro ? widget.onOpenProSpin : _watchAd,
            ),
    );
  }
}

class _ChestRow extends StatelessWidget {
  const _ChestRow({required this.quests, required this.done, required this.opening});

  final QuestState quests;
  final int done;
  final bool opening;

  @override
  Widget build(BuildContext context) {
    final bool ready = quests.chestReady;
    final (String subtitle, Widget trailing) = quests.chestOpened
        ? (quests.chestDoubled ? 'Opened and doubled' : 'Opened. A new one tomorrow.', const _Done())
        : ready
        ? (
            '${CoinPolicy.questChestMin} to ${CoinPolicy.questChestMax} coins',
            PrismButton(
              label: 'Open',
              size: PrismButtonSize.compact,
              loading: opening,
              onPressed: () => context.read<QuestsBloc>().add(const QuestsEvent.chestOpened()),
            ),
          )
        : (
            'Finish ${quests.items.length} quests · ${CoinPolicy.questChestMin} to ${CoinPolicy.questChestMax} coins',
            Text('$done of ${quests.items.length}', style: PrismTextStyles.caption(context)),
          );
    return _ItemRow(
      icon: quests.chestOpened
          ? Icons.inventory_2_outlined
          : ready
          ? Icons.redeem_rounded
          : Icons.lock_outline_rounded,
      title: 'Daily chest',
      subtitle: subtitle,
      semanticLabel:
          'Daily chest, ${quests.chestOpened
              ? 'opened'
              : ready
              ? 'ready to open'
              : 'locked'}. $subtitle',
      trailing: trailing,
    );
  }
}
