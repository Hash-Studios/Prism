import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_wall_tile.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// A grid of walls with the feed tile, so a tap opens the detail page and swipes through these walls.
class WallIdsGrid extends StatelessWidget {
  const WallIdsGrid({super.key, required this.walls, this.header});

  final List<PrismWallpaper> walls;

  /// Text above the grid, aligned with the page title.
  final String? header;

  @override
  Widget build(BuildContext context) {
    final List<FeedItemEntity> items = <FeedItemEntity>[
      for (final PrismWallpaper wall in walls) PrismFeedItem(id: wall.id, wallpaper: wall),
    ];
    final int columns = wallpaperGridColumns(MediaQuery.sizeOf(context).width);
    final int decodeHeight = gridTileDecodeHeight(context, crossAxisCount: columns);
    return CustomScrollView(
      slivers: <Widget>[
        if (header != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                PrismSpace.xs + 44 + PrismSpace.xxs,
                0,
                PrismSpace.page,
                PrismSpace.md,
              ),
              child: Text(header!, style: PrismTextStyles.body(context)),
            ),
          ),
        SliverPadding(
          padding: PrismFeedLayout.gridPadding,
          sliver: SliverGrid(
            gridDelegate: PrismWallGrid.delegate(
              context,
              footerHeight: favouriteFooterHeight,
              columns: columns,
              spacing: PrismFeedLayout.gridSpacing,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final FeedItemEntity item = items[index];
              return KeyedSubtree(
                key: ValueKey<String>(item.id),
                child: FeedWallTile(
                  item: item,
                  index: index,
                  crossAxisCount: columns,
                  memCacheHeight: decodeHeight,
                  feed: items,
                ),
              );
            }, childCount: items.length),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: PrismSpace.bottomBarClearance)),
      ],
    );
  }
}
