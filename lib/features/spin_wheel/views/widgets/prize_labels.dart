import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
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

String prizeTitle(WheelPrize prize) => switch (prize) {
  CoinsPrize(:final int coins) => '$coins coins',
  XpPrize(:final int xp) => '$xp XP',
  CosmeticPrize() => 'Mystery cosmetic',
};

/// The line under a prize's title, or null when it needs none.
String? prizeNote(WheelPrize prize) => switch (prize) {
  CosmeticPrize(:final int fallbackCoins) when fallbackCoins > 0 => 'Pays $fallbackCoins coins if you own them all',
  _ => null,
};
