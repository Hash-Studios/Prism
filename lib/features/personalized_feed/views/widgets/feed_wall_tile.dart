import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/premium_wall_utils.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_hero_card.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Whether a feed item belongs to a premium collection.
bool isPremiumFeedItem(FeedItemEntity item) => switch (item) {
  PrismFeedItem(:final wallpaper) => isPremiumWall(app_state.premiumCollections, wallpaper.collections ?? const []),
  _ => false,
};

/// One wallpaper in the home grid: a [WallpaperTile] with quick actions and a premium star.
class FeedWallTile extends StatelessWidget {
  const FeedWallTile({
    super.key,
    required this.item,
    required this.index,
    required this.crossAxisCount,
    required this.memCacheHeight,
    this.onShowLessLikeThis,
    this.onVisible,
  });

  final FeedItemEntity item;
  final int index;
  final int crossAxisCount;
  final int memCacheHeight;
  final VoidCallback? onVisible;

  /// Offers the personalized feed's real dismiss and undo flow.
  final VoidCallback? onShowLessLikeThis;

  @override
  Widget build(BuildContext context) {
    final Widget tile = WallpaperTile(
      item: item,
      index: index,
      crossAxisCount: crossAxisCount,
      memCacheHeight: memCacheHeight,
      onShowLessLikeThis: onShowLessLikeThis,
      onVisible: onVisible,
    );
    if (!isPremiumFeedItem(item)) return tile;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        tile,
        const Positioned(
          top: PrismSpace.xs,
          right: PrismSpace.xs,
          child: IgnorePointer(child: PremiumStarBadge()),
        ),
      ],
    );
  }
}
