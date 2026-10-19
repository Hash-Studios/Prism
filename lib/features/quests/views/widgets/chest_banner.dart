import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/daily_chest/daily_chest.dart';
import 'package:Prism/features/quests/biz/bloc/quests_bloc.j.dart';
import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:Prism/features/quests/domain/quest_catalog.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_palette.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The daily chest with its key pips and, until it opens, the booster that doubles it. The Open button opens the
/// daily chest page, which owns the paying and the opening.
/// [onOpenSpin] opens the spin machine. Pro users tap it from the booster strip.
class ChestBanner extends StatelessWidget {
  const ChestBanner({super.key, required this.board, this.onOpenSpin});

  final QuestBoard board;
  final VoidCallback? onOpenSpin;

  @override
  Widget build(BuildContext context) {
    final ChestBooster? booster = board.stage == ChestStage.opened ? null : board.booster;
    return PrismCard(
      padding: const EdgeInsets.all(PrismSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ChestRow(board: board),
          if (booster != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: PrismSpace.sm),
              child: Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
            ),
            _BoosterStrip(booster: booster, onOpenSpin: onOpenSpin),
          ],
        ],
      ),
    );
  }
}

class _ChestRow extends StatelessWidget {
  const _ChestRow({required this.board});

  final QuestBoard board;

  @override
  Widget build(BuildContext context) {
    final int total = board.daily.length;
    final int done = board.doneCount;
    final int chestXp = EconomyConfig.current.xp.activities.questChest;
    final Widget openButton = PrismButton(
      label: context.l10n.economyOpen,
      size: PrismButtonSize.compact,
      onPressed: () => unawaited(showDailyChest(context)),
    );
    final (String state, Widget trailing) = switch (board.stage) {
      ChestStage.paid => (context.l10n.economyChestReadyPaid(done, total), openButton),
      ChestStage.free => (context.l10n.economyChestReady, openButton),
      ChestStage.opened => (context.l10n.economyChestOpened, const _Done()),
    };
    final String caption = chestRowSubtitle(context.l10n, board.chest, doubled: board.doubled);
    final String? xpLine = board.stage != ChestStage.opened && chestXp > 0
        ? context.l10n.economyChestXpLine(chestXp)
        : null;
    return Row(
      children: <Widget>[
        // Only the description merges into one node; the trailing button stays reachable on its own.
        Expanded(
          child: Semantics(
            container: true,
            label: context.l10n.economyDailyChestSemantics(state, caption, (xpLine != null).toString(), xpLine ?? ''),
            excludeSemantics: true,
            child: Row(
              children: <Widget>[
                _ChestSlot(phase: board.stage == ChestStage.opened ? ChestPhase.spent : ChestPhase.ready),
                const SizedBox(width: PrismSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(context.l10n.economyDailyChestTitle, style: PrismTextStyles.cardTitle(context)),
                      Text(caption, style: PrismTextStyles.caption(context)),
                      if (xpLine != null) Text(xpLine, style: PrismTextStyles.caption(context)),
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

/// The box in an 88 slot, the size of the chest it replaces. The Lottie has wide margins for its float and its glow, so a
/// box of 88 draws a chest about 50 wide. The box is larger than its slot, and only its empty margin spills over.
class _ChestSlot extends StatelessWidget {
  const _ChestSlot({required this.phase});

  final ChestPhase phase;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 88,
    child: OverflowBox(maxWidth: 120, maxHeight: 120, child: ChestBox(phase: phase, size: 120)),
  );
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
  const _BoosterStrip({required this.booster, required this.onOpenSpin});

  final ChestBooster booster;
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
      adErrorMessage: context.l10n.economyAdNotCompleted,
    );
    if (credited) {
      toasts.success(context.l10n.economyCoinsEarned(reward));
      bloc.add(const QuestsEvent.refreshed());
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ChestBooster booster = widget.booster;
    final bool pro = booster.kind == BoosterKind.proSpin;
    final String title = booster.claimed
        ? context.l10n.economyChestDoubled
        : pro
        ? questInfo('pro_spin', context.l10n).title
        : watchAdOptionLabel(context.l10n);
    // The strip only shows while the chest can still be opened, so a booster that is not done is always first.
    final String caption = booster.claimed ? context.l10n.economyChestBonusDone : context.l10n.economyChestDoFirst;
    final Widget description = Semantics(
      container: true,
      label: context.l10n.economyChestBoosterSemantics(title, caption),
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
    );
    final Widget action = booster.claimed
        ? const _Done()
        : PrismButton(
            label: pro ? context.l10n.economySpin : context.l10n.economyWatchVideo,
            variant: PrismButtonVariant.tonal,
            size: PrismButtonSize.compact,
            loading: _loading,
            onPressed: pro ? widget.onOpenSpin : _watchAd,
          );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 400 || MediaQuery.textScalerOf(context).scale(1) > 1.2;
        if (compact && !booster.claimed) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              description,
              Align(alignment: AlignmentDirectional.centerEnd, child: action),
            ],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: description),
            const SizedBox(width: PrismSpace.sm),
            action,
          ],
        );
      },
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
