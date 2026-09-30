import 'dart:convert';

import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/data/feed_item_cache_codec.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:flutter_test/flutter_test.dart';

WallpaperCore _core(String id, WallpaperSource source) => WallpaperCore(
  id: id,
  source: source,
  fullUrl: 'https://example.com/$id.jpg',
  thumbnailUrl: 'https://example.com/$id-thumb.jpg',
  resolution: '1440x3200',
  sizeBytes: 1234,
  authorName: 'Author',
  authorEmail: 'author@example.com',
  category: 'nature',
  createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
  width: 1440,
  height: 3200,
);

/// What the cache does to a payload on disk.
Map<String, dynamic> _viaJson(FeedItemEntity item) =>
    jsonDecode(jsonEncode(encodeFeedItem(item))) as Map<String, dynamic>;

void main() {
  test('prism item survives a JSON round trip', () {
    final item = FeedItemEntity.prism(
      id: 'p1',
      wallpaper: PrismWallpaper(
        core: _core('p1', WallpaperSource.prism),
        collections: const <String>['minimal'],
        review: true,
        tags: const <String>['dark'],
        aiMetadata: const <String, Object?>{'model': 'x'},
        firestoreDocumentId: 'doc-p1',
      ),
    );

    final decoded = decodeFeedItem(_viaJson(item)) as PrismFeedItem?;

    expect(decoded, isNotNull);
    expect(decoded!.id, 'p1');
    expect(decoded.wallpaper.core.fullUrl, 'https://example.com/p1.jpg');
    expect(decoded.wallpaper.core.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(decoded.wallpaper.core.authorEmail, 'author@example.com');
    expect(decoded.wallpaper.collections, <String>['minimal']);
    expect(decoded.wallpaper.review, isTrue);
    expect(decoded.wallpaper.tags, <String>['dark']);
    expect(decoded.wallpaper.aiMetadata, <String, Object?>{'model': 'x'});
    expect(decoded.wallpaper.firestoreDocumentId, 'doc-p1');
  });

  test('wallhaven item survives a JSON round trip', () {
    final item = FeedItemEntity.wallhaven(
      id: 'w1',
      wallpaper: WallhavenWallpaper(
        core: _core('w1', WallpaperSource.wallhaven),
        views: 10,
        favorites: 3,
        dimensionX: 1920,
        dimensionY: 1080,
        colors: const <String>['#000000'],
        thumbs: const <String, String>{'original': 'https://example.com/o.jpg'},
        tags: const <String>['city'],
        sizeBytes: 99,
      ),
    );

    final decoded = decodeFeedItem(_viaJson(item)) as WallhavenFeedItem?;

    expect(decoded, isNotNull);
    expect(decoded!.wallpaper.views, 10);
    expect(decoded.wallpaper.dimensionX, 1920);
    expect(decoded.wallpaper.colors, <String>['#000000']);
    expect(decoded.wallpaper.thumbs, <String, String>{'original': 'https://example.com/o.jpg'});
    expect(decoded.wallpaper.tags, <String>['city']);
    expect(decoded.wallpaper.core.source, WallpaperSource.wallhaven);
  });

  test('cached Wallhaven crop URLs resolve to orig and are rewritten on save', () {
    const oldCropUrl = 'https://th.wallhaven.cc/lg/21/21276x.jpg';
    const originalUrl = 'https://th.wallhaven.cc/orig/21/21276x.jpg';
    final cached =
        decodeFeedItem(<String, dynamic>{
              'type': 'wallhaven',
              'id': '21276x',
              'wallpaper': <String, dynamic>{
                'core': <String, dynamic>{
                  'id': '21276x',
                  'source': 'wallhaven',
                  'fullUrl': 'https://wallhaven.cc/w/21276x',
                  'thumbnailUrl': oldCropUrl,
                },
              },
            })!
            as WallhavenFeedItem;

    expect(cached.wallpaper.core.thumbnailUrl, originalUrl);
    final encoded = encodeFeedItem(cached)['wallpaper']! as Map<String, Object?>;
    final core = encoded['core']! as Map<String, Object?>;
    expect(core['thumbnailUrl'], originalUrl);
  });

  test('pexels item survives a JSON round trip', () {
    final item = FeedItemEntity.pexels(
      id: 'x1',
      wallpaper: PexelsWallpaper(
        core: _core('x1', WallpaperSource.pexels),
        photographer: 'Pat',
        photographerUrl: 'https://pexels.com/pat',
        src: const PexelsSrc(original: 'https://example.com/orig.jpg', medium: 'https://example.com/med.jpg'),
      ),
    );

    final decoded = decodeFeedItem(_viaJson(item)) as PexelsFeedItem?;

    expect(decoded, isNotNull);
    expect(decoded!.wallpaper.photographer, 'Pat');
    expect(decoded.wallpaper.src!.original, 'https://example.com/orig.jpg');
    expect(decoded.wallpaper.src!.medium, 'https://example.com/med.jpg');
    expect(decoded.wallpaper.src!.large, isNull);
  });

  test('malformed entries decode to null', () {
    expect(decodeFeedItem(<String, dynamic>{}), isNull);
    expect(decodeFeedItem(<String, dynamic>{'type': 'prism', 'id': 'a'}), isNull);
    expect(
      decodeFeedItem(<String, dynamic>{
        'type': 'unknown',
        'id': 'a',
        'wallpaper': <String, dynamic>{'core': <String, dynamic>{}},
      }),
      isNull,
    );
  });
}
