import 'dart:async';
import 'dart:collection';

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/session/data/low_data_mode.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// How many tiles of a new page get their image fetched before the user scrolls to them.
const int kPrefetchTileCount = 24;

/// At most this many prefetch downloads run at once, across every grid.
const int kPrefetchMaxConcurrent = 4;

final Queue<Future<void> Function()> _pending = Queue<Future<void> Function()>();
int _inFlight = 0;

void _pump() {
  while (_inFlight < kPrefetchMaxConcurrent && _pending.isNotEmpty) {
    _inFlight++;
    unawaited(
      _pending.removeFirst()().whenComplete(() {
        _inFlight--;
        _pump();
      }),
    );
  }
}

/// How many tiles of a [columns]-wide grid fit on the first screen.
int visibleTileCount(BuildContext context, int columns) {
  final Size size = MediaQuery.sizeOf(context);
  final double tileHeight = size.width / columns / 0.5;
  return (size.height / tileHeight).ceil() * columns;
}

/// After the current frame, starts loading the thumbnails of [items] (skipping the first [skip], at most
/// [kPrefetchTileCount]) at the decode height the grid uses, so they are in the image cache when their tiles build.
/// Does nothing in Data saver mode.
void prefetchTileImages(BuildContext context, List<FeedItemEntity> items, {required int memCacheHeight, int skip = 0}) {
  if (LowDataMode.enabled.value) {
    return;
  }
  final List<String> urls = items
      .skip(skip)
      .take(kPrefetchTileCount)
      .map((item) => item.thumbnailUrl.trim())
      .where((url) => url.isNotEmpty)
      .toList();
  if (urls.isEmpty) {
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted || LowDataMode.enabled.value) return;
    for (final String url in urls) {
      _pending.add(() {
        if (!context.mounted || LowDataMode.enabled.value) {
          return Future<void>.value();
        }
        return precacheImage(
          ResizeImage(CachedNetworkImageProvider(url, cacheManager: PrismImageCache.instance), height: memCacheHeight),
          context,
          onError: (_, _) {},
        );
      });
    }
    _pump();
  });
  WidgetsBinding.instance.ensureVisualUpdate();
}
