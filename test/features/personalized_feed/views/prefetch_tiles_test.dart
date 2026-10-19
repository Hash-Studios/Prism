import 'dart:async';
import 'dart:io' show SocketException;

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/views/widgets/prefetch_tiles.dart';
import 'package:Prism/features/session/data/low_data_mode.dart';
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

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    return context;
  }

  void verifyFetched(String url, int times) {
    verify(
      () => cache.getFileStream(
        url,
        key: any(named: 'key'),
        headers: any(named: 'headers'),
        withProgress: any(named: 'withProgress'),
      ),
    ).called(times);
  }

  testWidgets('fetches nothing before the current frame ends, then the tile thumbnails through the cache', (
    tester,
  ) async {
    final BuildContext context = await pumpContext(tester);

    prefetchTileImages(context, <FeedItemEntity>[_item(0), _item(1)], memCacheHeight: 300);
    verifyNever(
      () => cache.getFileStream(
        any(),
        key: any(named: 'key'),
        headers: any(named: 'headers'),
        withProgress: any(named: 'withProgress'),
      ),
    );
    await tester.pump();
    await tester.pump();

    verifyFetched('https://example.com/w0-thumb.jpg', 1);
    verifyFetched('https://example.com/w1-thumb.jpg', 1);
  });

  testWidgets('skips the visible tiles and caps a page at 24', (tester) async {
    final BuildContext context = await pumpContext(tester);

    prefetchTileImages(context, <FeedItemEntity>[for (int i = 0; i < 40; i++) _item(i)], memCacheHeight: 300, skip: 6);
    for (int i = 0; i < 12; i++) {
      await tester.pump();
    }

    for (int i = 0; i < 6; i++) {
      verifyNever(
        () => cache.getFileStream(
          'https://example.com/w$i-thumb.jpg',
          key: any(named: 'key'),
          headers: any(named: 'headers'),
          withProgress: any(named: 'withProgress'),
        ),
      );
    }
    for (int i = 6; i < 6 + kPrefetchTileCount; i++) {
      verifyFetched('https://example.com/w$i-thumb.jpg', 1);
    }
    verifyNever(
      () => cache.getFileStream(
        'https://example.com/w${6 + kPrefetchTileCount}-thumb.jpg',
        key: any(named: 'key'),
        headers: any(named: 'headers'),
        withProgress: any(named: 'withProgress'),
      ),
    );
  });

  testWidgets('runs at most four downloads at once', (tester) async {
    final List<Completer<FileResponse>> opened = <Completer<FileResponse>>[];
    when(
      () => cache.getFileStream(
        any(),
        key: any(named: 'key'),
        headers: any(named: 'headers'),
        withProgress: any(named: 'withProgress'),
      ),
    ).thenAnswer((_) {
      final Completer<FileResponse> c = Completer<FileResponse>();
      opened.add(c);
      return Stream<FileResponse>.fromFuture(c.future);
    });
    final BuildContext context = await pumpContext(tester);

    prefetchTileImages(context, <FeedItemEntity>[for (int i = 0; i < 10; i++) _item(i)], memCacheHeight: 300);
    await tester.pump();
    await tester.pump();

    expect(opened, hasLength(kPrefetchMaxConcurrent));
    for (final Completer<FileResponse> c in opened.toList()) {
      c.completeError(const SocketException('offline'));
    }
    await tester.pump();
    await tester.pump();
    expect(opened.length, greaterThan(kPrefetchMaxConcurrent));
  });

  testWidgets('does nothing in Data saver mode', (tester) async {
    LowDataMode.enabled.value = true;
    addTearDown(() => LowDataMode.enabled.value = false);
    final BuildContext context = await pumpContext(tester);

    prefetchTileImages(context, <FeedItemEntity>[_item(0)], memCacheHeight: 300);
    await tester.pump();
    await tester.pump();

    verifyNever(
      () => cache.getFileStream(
        any(),
        key: any(named: 'key'),
        headers: any(named: 'headers'),
        withProgress: any(named: 'withProgress'),
      ),
    );
  });

  testWidgets('counts the tiles that fit on the first screen', (tester) async {
    final BuildContext context = await pumpContext(tester);

    expect(visibleTileCount(context, 2), 4);
  });
}
