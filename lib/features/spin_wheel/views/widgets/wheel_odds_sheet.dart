import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_prizes.dart';
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
              leading: _icon(o.prize),
              title: _title(o.prize),
              subtitle: _subtitle(o.prize),
              value: oddsLabel(o.percent),
            ),
        ],
      ),
    ),
  );
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

String _title(WheelPrize prize) => switch (prize) {
  CoinsPrize(:final int coins) => '$coins coins',
  XpPrize(:final int xp) => '$xp XP',
  CosmeticPrize() => 'Mystery cosmetic',
};

String? _subtitle(WheelPrize prize) => switch (prize) {
  CosmeticPrize(:final int fallbackCoins) when fallbackCoins > 0 => 'Pays $fallbackCoins coins if you own them all',
  _ => null,
};
