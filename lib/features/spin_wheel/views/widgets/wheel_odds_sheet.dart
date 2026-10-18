import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_prizes.dart';
import 'package:Prism/features/spin_wheel/views/widgets/prize_labels.dart';
import 'package:flutter/material.dart';

Future<void> showWheelOdds(BuildContext context, List<WheelSegment> segments) {
  final List<WheelOdds> odds = wheelOdds(segments);
  return showPrismSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => PrismSheetBody(
      title: 'The odds',
      message: 'Every spin pays something.',
      actions: <Widget>[
        PrismButton(
          label: 'Close',
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
              title: prizeTitle(o.prize),
              subtitle: prizeNote(o.prize),
              value: oddsLabel(o.percent),
            ),
        ],
      ),
    ),
  );
}
