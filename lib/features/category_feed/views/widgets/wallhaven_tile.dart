import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart' as wData;
import 'package:Prism/features/category_feed/views/widgets/wallhaven_grid.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class WallhavenTile extends StatelessWidget {
  const WallhavenTile({super.key, required this.widget, required this.index});

  final WallHavenGrid widget;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: wData.walls.isEmpty
              ? BoxDecoration(
                  color: context.prismModeStyleForContext() == "Dark"
                      ? Colors.white10
                      : Colors.black.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                )
              : BoxDecoration(
                  color: context.prismModeStyleForContext() == "Dark"
                      ? Colors.white10
                      : Colors.black.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(wData.walls[index].thumbs!["original"].toString()),
                    fit: BoxFit.cover,
                  ),
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
                if (wData.walls == []) {
                } else {
                  unawaited(
                    analytics.track(
                      SurfaceActionTappedEvent(
                        surface: AnalyticsSurfaceValue.homeWallhavenGrid,
                        action: AnalyticsActionValue.tileOpened,
                        sourceContext: 'home_wallhaven_grid_tile',
                        itemType: ItemTypeValue.wallpaper,
                        itemId: wData.walls[index].id.toString(),
                        index: index,
                      ),
                    ),
                  );
                  context.router.push(
                    WallpaperRoute(
                      provider: widget.provider.toString(),
                      index: index,
                      link: wData.walls[index].thumbs!["small"].toString(),
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
