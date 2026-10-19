import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_prizes.dart';
import 'package:Prism/features/spin_wheel/views/widgets/prize_labels.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

Future<void> showWheelOdds(BuildContext context, List<WheelSegment> segments) {
  final List<WheelOdds> odds = wheelOdds(segments);
  return showPrismSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => PrismSheetBody(
      title: context.l10n.economyOddsTitle,
      message: context.l10n.economyEverySpinPays,
      actions: <Widget>[
        PrismButton(
          label: sheetContext.l10n.actionClose,
          expand: true,
          variant: PrismButtonVariant.ghost,
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
      ],
      child: PrismGroup(
        children: <Widget>[
          for (final WheelOdds o in odds)
            PrismRow(
              leading: prizeIcon(o.prize),
              title: prizeTitle(o.prize, sheetContext.l10n),
              subtitle: prizeNote(o.prize, sheetContext.l10n),
              value: oddsLabel(o.percent, sheetContext.l10n),
            ),
        ],
      ),
    ),
  );
}
