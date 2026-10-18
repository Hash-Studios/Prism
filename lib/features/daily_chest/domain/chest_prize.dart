import 'package:Prism/core/coins/spin_wheel.dart';

/// The title of a chest slot in the odds sheet.
String chestPrizeTitle(WheelPrize prize) => switch (prize) {
  CoinsPrize(:final int coins) => '$coins coins',
  XpPrize(:final int xp) => '$xp XP',
  CosmeticPrize() => 'Mystery cosmetic',
};

/// The line under a slot's title, or null when it needs none.
String? chestPrizeNote(WheelPrize prize) => switch (prize) {
  CosmeticPrize(:final int fallbackCoins) when fallbackCoins > 0 => 'Pays $fallbackCoins coins if you own them all',
  _ => null,
};
