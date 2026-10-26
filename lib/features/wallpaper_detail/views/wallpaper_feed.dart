import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// One wall of a [WallpaperFeed]: its tile's position in the grid and its tile's Hero tag.
typedef WallpaperFeedTile = ({FeedItemEntity item, int index, String heroTag});

/// The grid a wallpaper detail page was opened from. The page swipes through [tiles]. On Back, [reveal] scrolls the
/// grid to the wall on screen, so the card can shrink into its tile.
final class WallpaperFeed {
  WallpaperFeed({required BuildContext grid, required List<WallpaperFeedTile> tiles, this.indexInGrid})
    : grid = _sliverGridContext(grid),
      tiles = List<WallpaperFeedTile>.unmodifiable(tiles);

  /// A context inside the grid: a tile, or the builder context of its delegate.
  final BuildContext grid;
  final List<WallpaperFeedTile> tiles;

  /// Resolves a feed item's current grid index after the underlying grid changes, or returns -1 if it was removed.
  final int Function(FeedItemEntity)? indexInGrid;

  static BuildContext _sliverGridContext(BuildContext context) {
    BuildContext? sliverGrid;
    context.visitAncestorElements((Element element) {
      if (element.widget is SliverGrid) {
        sliverGrid = element;
        return false;
      }
      return true;
    });
    return sliverGrid ?? context;
  }

  /// The position of [entity] in [tiles], or -1.
  int indexOf(FeedItemEntity entity) =>
      tiles.indexWhere((tile) => tile.item.source == entity.source && tile.item.id == entity.id);

  /// Jumps the grid so the tile at [position] is on screen. The grid lies under the detail page and lays out again on
  /// the first frame of Back, before the Hero looks for the tile. Does nothing when the tile is already on screen, or
  /// when the feed is not a grid.
  void reveal(int position) {
    if (!grid.mounted) return;
    final ScrollableState? scrollable = Scrollable.maybeOf(grid);
    RenderObject? node = grid.findRenderObject();
    while (node != null && node is! RenderSliver) {
      node = node.parent;
    }
    if (scrollable == null || node is! RenderSliverGrid || node.geometry == null) return;
    final ScrollPosition scroll = scrollable.position;
    if (!scroll.hasContentDimensions || !scroll.hasViewportDimension) return;
    final WallpaperFeedTile feedTile = tiles[position];
    final int index = indexInGrid?.call(feedTile.item) ?? feedTile.index;
    if (index < 0) return;
    final SliverGridGeometry tile = node.gridDelegate.getLayout(node.constraints).getGeometryForChildIndex(index);
    final double start = node.constraints.precedingScrollExtent + tile.scrollOffset;
    final double end = start + tile.mainAxisExtent;
    final double overlap = clampDouble(node.constraints.overlap, 0, scroll.viewportDimension);
    if (start >= scroll.pixels + overlap && end <= scroll.pixels + scroll.viewportDimension) return;
    final double centre = start + tile.mainAxisExtent / 2 - (scroll.viewportDimension + overlap) / 2;
    scroll.jumpTo(clampDouble(centre, scroll.minScrollExtent, scroll.maxScrollExtent));
  }
}
