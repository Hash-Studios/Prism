import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/premium_wall_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_hero_card.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Whether a feed item belongs to a premium collection.
bool isPremiumFeedItem(FeedItemEntity item) => switch (item) {
  PrismFeedItem(:final wallpaper) => isPremiumWall(app_state.premiumCollections, wallpaper.collections ?? const []),
  _ => false,
};

/// One wallpaper in the home grid. Opens the detail page, and offers [onLongPress] for "show less like this".
class FeedWallTile extends StatelessWidget {
  const FeedWallTile({super.key, required this.item, required this.index, this.onLongPress});

  final FeedItemEntity item;
  final int index;
  final VoidCallback? onLongPress;

  AnalyticsSurfaceValue get _surface => switch (item.source) {
    WallpaperSource.wallhaven => AnalyticsSurfaceValue.homeWallhavenGrid,
    WallpaperSource.pexels => AnalyticsSurfaceValue.homePexelsGrid,
    _ => AnalyticsSurfaceValue.homeWallpaperGrid,
  };

  String get _sourceContext => switch (item.source) {
    WallpaperSource.wallhaven => 'home_wallhaven_grid_tile',
    WallpaperSource.pexels => 'home_pexels_grid_tile',
    _ => 'home_wallpaper_grid_tile',
  };

  @override
  Widget build(BuildContext context) {
    final String heroTag = prismHeroTag(Scrollable.maybeOf(context) ?? context, index, item.id);
    return PrismWallTile(
      url: item.thumbnailUrl,
      heroTag: heroTag,
      semanticLabel: item.semanticLabel,
      onLongPress: onLongPress,
      onTap: () {
        unawaited(
          analytics.track(
            SurfaceActionTappedEvent(
              surface: _surface,
              action: AnalyticsActionValue.tileOpened,
              sourceContext: _sourceContext,
              itemType: ItemTypeValue.wallpaper,
              itemId: item.id,
              index: index,
            ),
          ),
        );
        context.router.push(WallpaperDetailRoute(entity: item, heroTag: heroTag));
      },
      overlay: isPremiumFeedItem(item)
          ? const IgnorePointer(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(padding: EdgeInsets.all(6), child: PremiumStarBadge()),
              ),
            )
          : null,
    );
  }
}
