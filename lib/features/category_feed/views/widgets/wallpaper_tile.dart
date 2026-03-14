import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class WallpaperTile extends StatelessWidget {
  const WallpaperTile({super.key, required this.item, required this.index});

  final PrismFeedItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: context.prismModeStyleForContext() == "Dark" ? Colors.white10 : Colors.black.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(20),
            image: DecorationImage(image: CachedNetworkImageProvider(item.wallpaper.thumbnailUrl), fit: BoxFit.cover),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
              highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
              onTap: () {
                unawaited(
                  analytics.track(
                    SurfaceActionTappedEvent(
                      surface: AnalyticsSurfaceValue.homeWallpaperGrid,
                      action: AnalyticsActionValue.tileOpened,
                      sourceContext: 'home_wallpaper_grid_tile',
                      itemType: ItemTypeValue.wallpaper,
                      itemId: item.id,
                      index: index,
                    ),
                  ),
                );
                context.router.push(WallpaperDetailRoute(entity: WallpaperDetailEntityX.fromFeedItem(item)));
              },
            ),
          ),
        ),
      ],
    );
  }
}
