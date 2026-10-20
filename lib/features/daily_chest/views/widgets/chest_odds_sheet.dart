import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/daily_chest/domain/chest_odds.dart';
import 'package:Prism/features/daily_chest/domain/chest_tiers.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_prizes.dart';
import 'package:Prism/features/spin_wheel/spin_wheel.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Lists every slot of the chest with its odds in percent, grouped by tier.
Future<void> showChestOdds(BuildContext context, List<WheelSegment> slots) {
  final List<ChestOddsGroup> groups = chestOddsByTier(slots);
  return showPrismSheet<void>(
    context,
    builder: (BuildContext sheetContext) => PrismSheetBody(
      title: context.l10n.economyOddsTitle,
      message: context.l10n.economyEveryChestPays,
      actions: <Widget>[
        PrismButton(
          label: context.l10n.actionClose,
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
                    leading: prizeIcon(o.prize),
                    title: prizeTitle(o.prize, context.l10n),
                    subtitle: prizeNote(o.prize, context.l10n),
                    value: oddsLabel(o.percent, context.l10n),
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
      label: context.l10n.economyOddsTierSemantics(
        group.tier.label(context.l10n),
        oddsLabel(group.percent, context.l10n),
      ),
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(color: group.tier.color, shape: BoxShape.circle),
            child: const SizedBox.square(dimension: 10),
          ),
          const SizedBox(width: PrismSpace.xs),
          Expanded(child: Text(group.tier.label(context.l10n), style: PrismTextStyles.rowTitle(context))),
          Text(oddsLabel(group.percent, context.l10n), style: PrismTextStyles.caption(context)),
        ],
      ),
    );
  }
}
