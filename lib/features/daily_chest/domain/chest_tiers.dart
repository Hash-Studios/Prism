import 'dart:ui';

import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/l10n/l10n.dart';

/// The rarity colours are game colours: a rare chest is blue on every theme and accent, like Glint's logo colours.
extension ChestTierLook on ChestTier {
  Color get color => switch (this) {
    ChestTier.common => const Color(0xFF34D399),
    ChestTier.rare => const Color(0xFF38BDF8),
    ChestTier.epic => const Color(0xFFA78BFA),
    ChestTier.legendary => const Color(0xFFF5B83D),
  };

  String label(AppLocalizations l10n) => switch (this) {
    ChestTier.common => l10n.economyChestTierCommon,
    ChestTier.rare => l10n.economyChestTierRare,
    ChestTier.epic => l10n.economyChestTierEpic,
    ChestTier.legendary => l10n.economyChestTierLegendary,
  };
}
