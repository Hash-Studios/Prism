import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// One wallpaper of a feed grid. It opens the wallpaper detail page and records the tap.
class WallpaperTile extends StatelessWidget {
  const WallpaperTile({super.key, required this.item, required this.index, this.memCacheHeight, this.crossAxisCount});

  final FeedItemEntity item;
  final int index;

  /// Kept for callers that still pass it. The shared tile decides the decode size.
  final int? memCacheHeight;

  /// Kept for callers that still pass it. The shared grid decides the column count.
  final int? crossAxisCount;

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
    );
  }
}
