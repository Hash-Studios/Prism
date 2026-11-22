import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// A compact price pill for tiles and the detail page. Locked shows the coin price. Unlocked shows a check and the
/// unlocked label. It sits on wallpaper images, so it uses a near-opaque page surface and grows with large text.
class CreatorPriceChip extends StatelessWidget {
  const CreatorPriceChip({super.key, required this.price, this.unlocked = false});

  final int price;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle style = PrismTextStyles.caption(
      context,
    ).copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600);
    return Semantics(
      label: unlocked ? l10n.creatorWallUnlockedBadge : l10n.creatorWallChipSemantics(price),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(PrismRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm, vertical: PrismSpace.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (unlocked)
                Icon(Icons.check_rounded, size: 14, color: scheme.primary)
              else
                const PrismCoinIcon(size: 14),
              const SizedBox(width: PrismSpace.xxs),
              Text(unlocked ? l10n.creatorWallUnlockedBadge : '$price', style: style),
            ],
          ),
        ),
      ),
    );
  }
}
