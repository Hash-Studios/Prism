import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/daily_chest/domain/chest_odds.dart';
import 'package:Prism/features/daily_chest/domain/chest_prize.dart';
import 'package:Prism/features/daily_chest/domain/chest_tiers.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_prizes.dart';
import 'package:flutter/material.dart';

/// Lists every slot of the chest with its odds in percent, grouped by tier.
Future<void> showChestOdds(BuildContext context, List<WheelSegment> slots) {
  final List<ChestOddsGroup> groups = chestOddsByTier(slots);
  return showPrismSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => PrismSheetBody(
      title: 'The odds',
      message: 'Every chest pays something.',
      actions: <Widget>[
        PrismButton(
          label: 'Close',
          expand: true,
          variant: PrismButtonVariant.ghost,
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (int i, ChestOddsGroup group) in groups.indexed) ...<Widget>[
            if (i > 0) const SizedBox(height: PrismSpace.md),
            _TierHeader(group: group),
            const SizedBox(height: PrismSpace.xs),
            PrismGroup(
              children: <Widget>[
                for (final WheelOdds o in group.rows)
                  PrismRow(
                    leading: _icon(o.prize),
                    title: chestPrizeTitle(o.prize),
                    subtitle: chestPrizeNote(o.prize),
                    value: oddsLabel(o.percent),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class _TierHeader extends StatelessWidget {
  const _TierHeader({required this.group});

  final ChestOddsGroup group;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: '${group.tier.label}, ${oddsLabel(group.percent)}',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(color: group.tier.color, shape: BoxShape.circle),
            child: const SizedBox.square(dimension: 10),
          ),
          const SizedBox(width: PrismSpace.xs),
          Expanded(child: Text(group.tier.label, style: PrismTextStyles.rowTitle(context))),
          Text(oddsLabel(group.percent), style: PrismTextStyles.caption(context)),
        ],
      ),
    );
  }
}

Widget _icon(WheelPrize prize) => SizedBox.square(
  dimension: 32,
  child: Center(
    child: switch (prize) {
      CoinsPrize() => const PrismCoinIcon(size: 24),
      XpPrize() => const Icon(Icons.bolt_rounded, size: 24),
      CosmeticPrize() => const Icon(Icons.auto_awesome_rounded, size: 24),
    },
  ),
);
