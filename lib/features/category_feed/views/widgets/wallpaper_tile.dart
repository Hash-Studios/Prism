import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class WallpaperTile extends StatelessWidget {
  const WallpaperTile({super.key, required this.item, required this.index, this.memCacheHeight, this.crossAxisCount});

  final FeedItemEntity item;
  final int index;
  final int? memCacheHeight;

  /// When null, uses the app's standard grid (3 columns portrait, 5 landscape).
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
    final columns = crossAxisCount ?? (MediaQuery.orientationOf(context) == Orientation.portrait ? 3 : 5);
    final width = (MediaQuery.sizeOf(context).width / columns).toInt();
    final height = memCacheHeight ?? (width * 2 * 1.5).toInt();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
        highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
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
          context.router.push(WallpaperDetailRoute(entity: WallpaperDetailEntityX.fromFeedItem(item)));
        },
        child: CachedNetworkImage(
          imageUrl: item.thumbnailUrl,
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero,
          memCacheHeight: height,
          placeholder: (ctx, _) => ColoredBox(color: Theme.of(ctx).colorScheme.surfaceContainerHighest),
          errorWidget: (ctx, _, _) => ColoredBox(color: Theme.of(ctx).colorScheme.surfaceContainerHighest),
        ),
      ),
    );
  }
}
