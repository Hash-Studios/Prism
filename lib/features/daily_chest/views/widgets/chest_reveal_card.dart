import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/daily_chest/domain/chest_tiers.dart';
import 'package:Prism/features/quests/domain/quest_catalog.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/features/shop/views/widgets/shop_item_preview.dart';
import 'package:Prism/features/spin_wheel/spin_wheel.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_color_scheme.dart';
import 'package:flutter/material.dart';

/// What the chest held: its rarity, the prize, a line that says how it was paid and the XP the open granted.
class ChestRevealCard extends StatelessWidget {
  const ChestRevealCard({super.key, required this.won});

  final ChestWon won;

  /// The shop item a cosmetic prize paid, or null.
  ShopItem? get _item {
    final String? id = won.win.itemId;
    return id == null ? null : shopItem(id);
  }

  bool get _isCosmetic => won.prize is CosmeticPrize && won.win.itemId != null;

  /// The cosmetic itself is not doubled, only coins are.
  bool get _showsDouble => won.doubled && !_isCosmetic;

  String _semanticLabel(AppLocalizations l10n) {
    final String prize = _isCosmetic
        ? l10n.economyChestNewCosmetic(_kindLabel(l10n, _item), _itemName(l10n))
        : l10n.economyChestCoinsPrize(won.win.coins);
    return l10n.economyChestPrizeSemantics(won.tier.label(l10n), prize, _showsDouble ? 'true' : 'false', won.win.xp);
  }

  String _itemName(AppLocalizations l10n) {
    final ShopItem? item = _item;
    return item == null ? cosmeticName(l10n) : shopItemName(item, l10n);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color tier = won.tier.color;
    final TextStyle caption = PrismTextStyles.caption(context);
    return Semantics(
      liveRegion: true,
      label: _semanticLabel(context.l10n),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(PrismRadius.lg),
          border: Border.all(color: tier.withValues(alpha: 0.55), width: 1.4),
          boxShadow: <BoxShadow>[BoxShadow(color: tier.withValues(alpha: 0.32), blurRadius: 32, spreadRadius: -4)],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.lg, vertical: PrismSpace.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _TierChip(tier: won.tier),
              const SizedBox(height: PrismSpace.xs),
              if (_isCosmetic) _cosmetic(context) else _amount(context),
              if (won.prize is CosmeticPrize && !_isCosmetic) ...<Widget>[
                const SizedBox(height: PrismSpace.xxs),
                Text(context.l10n.economyChestOwnEveryCosmetic, style: caption),
              ],
              if (_showsDouble) ...<Widget>[
                const SizedBox(height: PrismSpace.xxs),
                Text(context.l10n.economyChestDoubledByBonus, style: caption),
              ],
              if (won.win.xp > 0) ...<Widget>[
                const SizedBox(height: PrismSpace.xxs),
                Text(context.l10n.economyXpAwarded(won.win.xp), style: caption),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _amount(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextStyle numeral = PrismTextStyles.numeral(context, 44).copyWith(color: cs.onSurface);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const PrismCoinIcon(size: 36),
        const SizedBox(width: PrismSpace.xs),
        CountUp(value: won.win.coins, style: numeral),
      ],
    );
  }

  Widget _cosmetic(BuildContext context) {
    final ShopItem? item = _item;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (item != null) ...<Widget>[ShopItemPreview(item: item, size: 56), const SizedBox(width: PrismSpace.sm)],
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _itemName(context.l10n),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PrismTextStyles.sectionTitle(context),
              ),
              Text(
                context.l10n.economyChestNewKind(_kindLabel(context.l10n, item)),
                style: PrismTextStyles.caption(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _kindLabel(AppLocalizations l10n, ShopItem? item) => switch (item?.kind) {
  ShopItemKind.theme => l10n.economyCosmeticTheme,
  ShopItemKind.appIcon => l10n.economyCosmeticAppIcon,
  ShopItemKind.frame => l10n.economyCosmeticFrame,
  ShopItemKind.nameGlow => l10n.economyCosmeticNameGlow,
  null => l10n.economyCosmetic,
};

class _TierChip extends StatelessWidget {
  const _TierChip({required this.tier});

  final ChestTier tier;

  @override
  Widget build(BuildContext context) {
    final Color fill = tier.color;
    return DecoratedBox(
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(PrismRadius.pill)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm, vertical: 3),
        child: Text(
          tier.label(context.l10n),
          style: PrismTextStyles.caption(context).copyWith(color: prismOnColor(fill), fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
