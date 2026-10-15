import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/premium_wall_utils.dart';
import 'package:Prism/core/widgets/home/premium_corner_banner.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/source_feed_grid.dart';
import 'package:flutter/material.dart';

class WallpaperGrid extends StatelessWidget {
  const WallpaperGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5.0),
      child: SourceFeedGrid<PrismFeedItem>(
        surface: AnalyticsSurfaceValue.homeWallpaperGrid,
        listName: ScrollListNameValue.wallpaperGrid,
        sourceContextPrefix: 'home_wallpaper_grid',
        itemWrapper: (context, item, tile) => PremiumCornerBanner(
          isPremiumWall: isPremiumWall(app_state.premiumCollections, item.wallpaper.collections ?? const <String>[]),
          child: tile,
        ),
      ),
    );
  }
}
