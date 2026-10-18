import 'dart:ui';

import 'package:Prism/core/coins/daily_chest.dart';

/// The rarity colours are game colours: a rare chest is blue on every theme and accent, like Glint's logo colours.
extension ChestTierLook on ChestTier {
  Color get color => switch (this) {
    ChestTier.common => const Color(0xFF34D399),
    ChestTier.rare => const Color(0xFF38BDF8),
    ChestTier.epic => const Color(0xFFA78BFA),
    ChestTier.legendary => const Color(0xFFF5B83D),
  };

  String get label => switch (this) {
    ChestTier.common => 'Common',
    ChestTier.rare => 'Rare',
    ChestTier.epic => 'Epic',
    ChestTier.legendary => 'Legendary',
  };
}
