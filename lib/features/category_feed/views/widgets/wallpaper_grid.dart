import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/premium_wall_utils.dart';
import 'package:Prism/core/widgets/premium_banners/premium_banner.dart';
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
        physics: const ScrollPhysics(),
        itemWrapper: (context, item, tile) => PremiumBanner(
          comparator: !isPremiumWall(app_state.premiumCollections, item.wallpaper.collections ?? const <String>[]),
          top: (MediaQuery.of(context).size.width / 2) / 0.6225 - 68,
          left: MediaQuery.of(context).size.width / 2 - 53.5,
          right: null,
          bottom: null,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
          iconSize: 24,
          iconPadding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
          fit: StackFit.loose,
          clipBehavior: Clip.hardEdge,
          child: tile,
        ),
      ),
    );
  }
}
