import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FeedItemEntity item(WallpaperSource source, String id, String url) {
    final core = WallpaperCore(id: id, source: source, fullUrl: url, thumbnailUrl: '');
    return switch (source) {
      WallpaperSource.prism => FeedItemEntity.prism(
        id: id,
        wallpaper: PrismWallpaper(core: core),
      ),
      WallpaperSource.wallhaven => FeedItemEntity.wallhaven(
        id: id,
        wallpaper: WallhavenWallpaper(core: core),
      ),
      WallpaperSource.pexels => FeedItemEntity.pexels(
        id: id,
        wallpaper: PexelsWallpaper(core: core),
      ),
      _ => throw ArgumentError.value(source),
    };
  }

  test('normalizes URL identity across sources and IDs', () {
    final prism = item(WallpaperSource.prism, 'One', '  HTTPS://Example.com/Wall.JPG  ');
    final pexels = item(WallpaperSource.pexels, 'Two', 'https://example.com/wall.jpg');
    expect(prism.canonicalKey, 'https://example.com/wall.jpg');
    expect(prism.canonicalKey, pexels.canonicalKey);
  });

  test('empty URLs fall back to normalized source and item ID', () {
    expect(item(WallpaperSource.prism, '  AbC  ', ' \t ').canonicalKey, 'prism:abc');
    expect(item(WallpaperSource.wallhaven, '  AbC  ', '').canonicalKey, 'wallhaven:abc');
    expect(item(WallpaperSource.pexels, '  AbC  ', '').canonicalKey, 'pexels:abc');
    expect(item(WallpaperSource.prism, ' ', '').canonicalKey, 'prism:');
  });
}
