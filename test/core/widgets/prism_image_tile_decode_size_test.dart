import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const FeedItemEntity _item = WallhavenFeedItem(
  id: 'wall',
  wallpaper: WallhavenWallpaper(
    core: WallpaperCore(
      id: 'wall',
      source: WallpaperSource.wallhaven,
      fullUrl: 'https://example.test/full.jpg',
      thumbnailUrl: 'https://example.test/thumb.jpg',
      authorName: 'Author',
    ),
  ),
);

void main() {
  testWidgets('defaults decode to the laid-out height in physical pixels and keeps its hero', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 90,
            height: 120,
            child: PrismImageTile(url: 'https://example.test/wall.jpg', heroTag: 'wall'),
          ),
        ),
      ),
    );

    final CachedNetworkImage image = tester.widget(find.byType(CachedNetworkImage));
    expect(image.memCacheHeight, 240);
    expect(tester.widget<Hero>(find.byType(Hero)).tag, 'wall');
  });

  testWidgets('WallpaperTile forwards its retained decode-height argument', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(width: 90, height: 120, child: WallpaperTile(item: _item, index: 0, memCacheHeight: 360)),
        ),
      ),
    );

    expect(tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).memCacheHeight, 360);
    expect(tester.widget<Hero>(find.byType(Hero)).tag, startsWith('wall-'));
  });

  testWidgets('WallpaperTile keeps its crossAxisCount decode-height override', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: WallpaperTile(item: _item, index: 0, crossAxisCount: 3)));

    expect(tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).memCacheHeight, 400);
  });
}
