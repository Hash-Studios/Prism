import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

Widget prizeIcon(WheelPrize prize) => SizedBox.square(
  dimension: 32,
  child: Center(
    child: switch (prize) {
      CoinsPrize() => const PrismCoinIcon(size: 24),
      XpPrize() => const Icon(Icons.bolt_rounded, size: 24),
      CosmeticPrize() => const Icon(Icons.auto_awesome_rounded, size: 24),
    },
  ),
);

String prizeTitle(WheelPrize prize, AppLocalizations l10n) => switch (prize) {
  CoinsPrize(:final int coins) => l10n.economyCoins(coins),
  XpPrize(:final int xp) => l10n.economyXp(xp),
  CosmeticPrize() => l10n.economyMysteryCosmetic,
};

/// The line under a prize's title, or null when it needs none.
String? prizeNote(WheelPrize prize, AppLocalizations l10n) => switch (prize) {
  CosmeticPrize(:final int fallbackCoins) when fallbackCoins > 0 => l10n.economyFallbackCoins(fallbackCoins),
  _ => null,
};
