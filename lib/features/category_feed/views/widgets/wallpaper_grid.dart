import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/premium_wall_utils.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/premium_tile_badge.dart';
import 'package:Prism/features/category_feed/views/widgets/source_feed_grid.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

class WallpaperGrid extends StatelessWidget {
  const WallpaperGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return SourceFeedGrid<PrismFeedItem>(
      surface: AnalyticsSurfaceValue.homeWallpaperGrid,
      listName: ScrollListNameValue.wallpaperGrid,
      sourceContextPrefix: 'home_wallpaper_grid',
      itemWrapper: (context, item, tile) {
        if (!isPremiumWall(app_state.premiumCollections, item.wallpaper.collections ?? const <String>[])) return tile;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            tile,
            const Positioned(
              top: PrismSpace.xs,
              right: PrismSpace.xs,
              child: IgnorePointer(child: PremiumTileBadge()),
            ),
          ],
        );
      },
    );
  }
}
