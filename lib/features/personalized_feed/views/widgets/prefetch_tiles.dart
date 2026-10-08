import 'dart:async';

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// How many tiles of a new page get their image fetched before the user scrolls to them.
const int kPrefetchTileCount = 6;

/// Starts loading the thumbnails of the first [kPrefetchTileCount] of [items] at the decode height the grid uses,
/// so they are in the image cache when their tiles build.
void prefetchTileImages(BuildContext context, List<FeedItemEntity> items, {required int memCacheHeight}) {
  for (final FeedItemEntity item in items.take(kPrefetchTileCount)) {
    unawaited(
      precacheImage(
        ResizeImage(
          CachedNetworkImageProvider(item.thumbnailUrl, cacheManager: PrismImageCache.instance),
          height: memCacheHeight,
        ),
        context,
        onError: (_, _) {},
      ),
    );
  }
}
