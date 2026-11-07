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

  group('distinctWalls', () {
    FeedItemEntity upload(String id, int bytes, List<String> colours) => FeedItemEntity.wallhaven(
      id: id,
      wallpaper: WallhavenWallpaper(
        core: WallpaperCore(
          id: id,
          source: WallpaperSource.wallhaven,
          fullUrl: 'https://w.wallhaven.cc/full/$id.jpg',
          thumbnailUrl: '',
          sizeBytes: bytes,
        ),
        dimensionX: 3840,
        dimensionY: 5238,
        colors: colours,
      ),
    );
    const List<String> red = <String>['#cccccc', '#000000', '#660000', '#990000', '#424153'];
    const List<String> gold = <String>['#663300', '#000000', '#996633', '#424153', '#cc6633'];

    test('keeps distinct Wallhaven uploads even when metadata suggests a re-upload', () {
      final List<FeedItemEntity> walls = distinctWalls(<FeedItemEntity>[
        upload('7jmgk3', 17913092, red),
        upload('6l7j1q', 17905666, red),
        upload('jer9jm', 19445274, gold),
        upload('5y6l53', 20870143, gold),
      ]);
      expect(walls.map((FeedItemEntity wall) => wall.id), <String>['7jmgk3', '6l7j1q', 'jer9jm', '5y6l53']);
    });

    test('keeps different uploads when metadata happens to match', () {
      final List<FeedItemEntity> walls = distinctWalls(<FeedItemEntity>[
        upload('first', 17913092, red),
        upload('second', 17913092, red),
      ]);

      expect(walls.map((FeedItemEntity wall) => wall.id), <String>['first', 'second']);
    });

    test('drops a repeated source and id, and every wall in exclude', () {
      final List<FeedItemEntity> walls = distinctWalls(
        <FeedItemEntity>[
          item(WallpaperSource.prism, 'a', 'https://example.com/a.jpg'),
          item(WallpaperSource.prism, 'a', 'https://example.com/a-2.jpg'),
          item(WallpaperSource.wallhaven, 'a', ''),
          upload('6l7j1q', 17905666, red),
          item(WallpaperSource.prism, 'current', ''),
        ],
        exclude: <FeedItemEntity>[item(WallpaperSource.prism, 'current', ''), upload('7jmgk3', 17913092, red)],
      );
      expect(walls.map((FeedItemEntity wall) => '${wall.source.name}:${wall.id}'), <String>[
        'prism:a',
        'wallhaven:a',
        'wallhaven:6l7j1q',
      ]);
    });
  });
}
