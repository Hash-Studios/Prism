import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/quests/biz/bloc/quests_bloc.j.dart';
import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:Prism/features/quests/domain/quest_catalog.dart';
import 'package:Prism/features/quests/views/widgets/chest_art.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_palette.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The daily chest with its key pips and, until it opens, the booster that doubles it.
/// [onOpenSpin] opens the spin machine. Pro users tap it from the booster strip.
class ChestBanner extends StatelessWidget {
  const ChestBanner({super.key, required this.board, required this.opening, this.onOpenSpin});

  final QuestBoard board;
  final bool opening;
  final VoidCallback? onOpenSpin;

  @override
  Widget build(BuildContext context) {
    final ChestBooster? booster = board.chest == ChestStage.opened ? null : board.booster;
    return PrismCard(
      padding: const EdgeInsets.all(PrismSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ChestRow(board: board, opening: opening),
          if (booster != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: PrismSpace.sm),
              child: Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
            ),
            _BoosterStrip(booster: booster, chestReady: board.chest == ChestStage.ready, onOpenSpin: onOpenSpin),
          ],
        ],
      ),
    );
  }
}

class _ChestRow extends StatelessWidget {
  const _ChestRow({required this.board, required this.opening});

  final QuestBoard board;
  final bool opening;

  @override
  Widget build(BuildContext context) {
    final int total = board.daily.length;
    final int done = board.doneCount;
    final int chestXp = EconomyConfig.current.xp.activities.questChest;
    final (String caption, String state, Widget trailing) = switch (board.chest) {
      ChestStage.locked => (
        'Finish $total quests to open it',
        'locked. $done of $total quests done',
        ExcludeSemantics(child: Text('$done of $total', style: PrismTextStyles.caption(context))),
      ),
      ChestStage.ready => (
        '${CoinPolicy.questChestMin} to ${CoinPolicy.questChestMax} coins${chestXp > 0 ? ' and $chestXp XP' : ''}, '
            'maybe a cosmetic',
        'ready to open',
        PrismButton(
          label: 'Open',
          size: PrismButtonSize.compact,
          loading: opening,
          onPressed: () => context.read<QuestsBloc>().add(const QuestsEvent.chestOpened()),
        ),
      ),
      ChestStage.opened => (
        board.doubled ? 'Opened and doubled. A new one tomorrow.' : 'Opened. A new one tomorrow.',
        'opened',
        const _Done(),
      ),
    };
    return Row(
      children: <Widget>[
        // Only the description merges into one node; the trailing button stays reachable on its own.
        Expanded(
          child: Semantics(
            container: true,
            label: 'Daily chest, $state. $caption',
            excludeSemantics: true,
            child: Row(
              children: <Widget>[
                LiveChest(stage: board.chest, size: 88),
                const SizedBox(width: PrismSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('Daily chest', style: PrismTextStyles.cardTitle(context)),
                      Text(caption, style: PrismTextStyles.caption(context)),
                      const SizedBox(height: PrismSpace.xs),
                      _KeyPips(done: done, total: total),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: PrismSpace.sm),
        trailing,
      ],
    );
  }
}

class _KeyPips extends StatelessWidget {
  const _KeyPips({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: PrismSpace.xxs,
    runSpacing: PrismSpace.xxs,
    children: <Widget>[for (int i = 0; i < total; i++) _Pip(filled: i < done)],
  );
}

class _Pip extends StatelessWidget {
  const _Pip({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(PrismRadius.pill);
    return SizedBox(
      width: 22,
      height: 8,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.1), borderRadius: radius),
          ),
          AnimatedOpacity(
            opacity: filled ? 1 : 0,
            duration: context.motion(PrismDurations.base),
            curve: PrismCurves.enter,
            child: DecoratedBox(
              decoration: BoxDecoration(color: cs.primary, borderRadius: radius),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoosterStrip extends StatefulWidget {
  const _BoosterStrip({required this.booster, required this.chestReady, required this.onOpenSpin});

  final ChestBooster booster;
  final bool chestReady;
  final VoidCallback? onOpenSpin;

  @override
  State<_BoosterStrip> createState() => _BoosterStripState();
}

class _BoosterStripState extends State<_BoosterStrip> {
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
    final ChestBooster booster = widget.booster;
    final bool pro = booster.kind == BoosterKind.proSpin;
    final String title = booster.claimed
        ? 'Chest doubled'
        : pro
        ? questInfo('pro_spin').title
        : watchAdOptionLabel();
    final String caption = booster.claimed
        ? 'Your bonus is done'
        : widget.chestReady
        ? 'Do this first to double your chest'
        : 'Doubles your chest';
    return Row(
      children: <Widget>[
        // Only the description merges into one node; the trailing button stays reachable on its own.
        Expanded(
          child: Semantics(
            container: true,
            label: '$title. $caption',
            excludeSemantics: true,
            child: Row(
              children: <Widget>[
                const _DoubleTag(),
                const SizedBox(width: PrismSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(title, style: PrismTextStyles.rowTitle(context)),
                      Text(caption, style: PrismTextStyles.caption(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: PrismSpace.sm),
        if (booster.claimed)
          const _Done()
        else
          PrismButton(
            label: pro ? 'Spin' : 'Watch',
            variant: PrismButtonVariant.tonal,
            size: PrismButtonSize.compact,
            loading: _loading,
            onPressed: pro ? widget.onOpenSpin : _watchAd,
          ),
      ],
    );
  }
}

class _DoubleTag extends StatelessWidget {
  const _DoubleTag();

  @override
  Widget build(BuildContext context) {
    final WheelGold gold = WheelGold();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gold.base,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: gold.ink, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs, vertical: PrismSpace.xxs),
        child: Text(
          '×2',
          style: PrismTextStyles.cardTitle(context).copyWith(color: gold.ink, fontWeight: FontWeight.w800, height: 1.1),
        ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done();

  @override
  Widget build(BuildContext context) => const Icon(Icons.check_rounded, size: 22, color: PrismColors.success);
}
