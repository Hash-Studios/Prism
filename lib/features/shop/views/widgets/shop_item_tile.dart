import 'dart:math' as math;

import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/features/shop/views/widgets/shop_item_preview.dart';
import 'package:Prism/features/shop/views/widgets/shop_labels.dart';
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

  (String, PrismTone)? get _tag {
    if (owned) return equipped ? ('Equipped', PrismTone.accent) : ('Owned', PrismTone.success);
    if (item.rankReward != null) return ('Earned at ${shopRankName(item.rankReward!)}', PrismTone.accent);
    return switch (availability) {
      ShopAvailability.soldOut => ('Sold out', PrismTone.neutral),
      ShopAvailability.proOnly => ('Pro', PrismTone.accent),
      ShopAvailability.rankLocked => ('${shopRankName(item.requiredRank ?? '')} rank', PrismTone.warning),
      ShopAvailability.available => item.founders ? ('Until ${shopUntilLabel() ?? 'soon'}', PrismTone.warning) : null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final (String, PrismTone)? tag = _tag;
    final bool showPrice = !owned && item.rankReward == null && availability != ShopAvailability.soldOut;
    final int price = shopPriceFor(item);
    return PrismCard(
      padding: const EdgeInsets.all(PrismSpace.sm),
      onTap: onTap,
      semanticLabel: '${item.name}, ${tag?.$1 ?? '$price coins'}',
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
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: PrismTextStyles.rowTitle(context)),
          const SizedBox(height: PrismSpace.xxs),
          Row(
            children: <Widget>[
              if (showPrice) ...<Widget>[
                const PrismCoinIcon(size: 16),
                const SizedBox(width: 4),
                Text('$price', style: PrismTextStyles.body(context)),
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
