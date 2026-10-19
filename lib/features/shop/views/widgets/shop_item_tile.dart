import 'dart:math' as math;

import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/features/shop/views/widgets/shop_item_preview.dart';
import 'package:Prism/features/shop/views/widgets/shop_labels.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

class ShopItemTile extends StatelessWidget {
  const ShopItemTile({
    super.key,
    required this.item,
    required this.owned,
    required this.equipped,
    required this.availability,
    required this.onTap,
  });

  final ShopItem item;
  final bool owned;
  final bool equipped;
  final ShopAvailability availability;
  final VoidCallback onTap;

  (String, PrismTone)? _tag(AppLocalizations l10n) {
    if (owned) return equipped ? (l10n.economyEquipped, PrismTone.accent) : (l10n.economyOwned, PrismTone.success);
    if (item.rankReward != null)
      return (l10n.economyEarnedAtRank(shopRankName(item.rankReward!, l10n)), PrismTone.accent);
    return switch (availability) {
      ShopAvailability.soldOut => (l10n.economySoldOut, PrismTone.neutral),
      ShopAvailability.proOnly => (l10n.economyPro, PrismTone.accent),
      ShopAvailability.rankLocked => (
        l10n.economyRankTag(shopRankName(item.requiredRank ?? '', l10n)),
        PrismTone.warning,
      ),
      ShopAvailability.available =>
        item.founders ? (l10n.economyUntil(shopUntilLabel(l10n) ?? l10n.economySoon), PrismTone.warning) : null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final (String, PrismTone)? tag = _tag(context.l10n);
    final bool showPrice = !owned && item.rankReward == null && availability != ShopAvailability.soldOut;
    final int price = shopPriceFor(item);
    final String name = shopItemName(item, context.l10n);
    return PrismCard(
      padding: const EdgeInsets.all(PrismSpace.sm),
      onTap: onTap,
      semanticLabel: context.l10n.economyShopItemSemantics(name, tag?.$1 ?? context.l10n.economyCoins(price)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: item.kind == ShopItemKind.appIcon
                ? LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) => Center(
                      child: ShopItemPreview(item: item, size: math.min(box.maxWidth, box.maxHeight)),
                    ),
                  )
                : Center(child: ShopItemPreview(item: item, size: 80)),
          ),
          const SizedBox(height: PrismSpace.xs),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: PrismTextStyles.rowTitle(context)),
          const SizedBox(height: PrismSpace.xxs),
          Row(
            children: <Widget>[
              if (showPrice) ...<Widget>[
                const PrismCoinIcon(size: 16),
                const SizedBox(width: 4),
                Text(formatLocalizedNumber(price, context.l10n), style: PrismTextStyles.body(context)),
                const SizedBox(width: PrismSpace.xs),
              ],
              if (tag != null)
                Flexible(
                  child: PrismTag(label: tag.$1, tone: tag.$2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
