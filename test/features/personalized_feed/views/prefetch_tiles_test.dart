import 'dart:io' show SocketException;

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/views/widgets/prefetch_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCacheManager extends Mock implements BaseCacheManager {}

FeedItemEntity _item(int i) => FeedItemEntity.prism(
  id: 'w$i',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: 'w$i',
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/w$i.jpg',
      thumbnailUrl: 'https://example.com/w$i-thumb.jpg',
    ),
  ),
);

void main() {
  late _MockCacheManager cache;

  setUp(() {
    cache = _MockCacheManager();
    PrismImageCache.testOverride = cache;
    when(
      () => cache.getFileStream(
        any(),
        key: any(named: 'key'),
        headers: any(named: 'headers'),
        withProgress: any(named: 'withProgress'),
      ),
    ).thenAnswer((_) => Stream<FileResponse>.error(const SocketException('offline')));
  });

  tearDown(() {
    PrismImageCache.testOverride = null;
    PaintingBinding.instance.imageCache.clear();
  });

  testWidgets('starts loading the thumbnails of the first six items, through the Prism image cache', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );

    prefetchTileImages(context, <FeedItemEntity>[for (int i = 0; i < 10; i++) _item(i)], memCacheHeight: 300);
    await tester.pump();

    for (int i = 0; i < kPrefetchTileCount; i++) {
      verify(
        () => cache.getFileStream(
          'https://example.com/w$i-thumb.jpg',
          key: any(named: 'key'),
          headers: any(named: 'headers'),
          withProgress: any(named: 'withProgress'),
        ),
      ).called(1);
    }
    verifyNever(
      () => cache.getFileStream(
        'https://example.com/w$kPrefetchTileCount-thumb.jpg',
        key: any(named: 'key'),
        headers: any(named: 'headers'),
        withProgress: any(named: 'withProgress'),
      ),
    );
  });
}
