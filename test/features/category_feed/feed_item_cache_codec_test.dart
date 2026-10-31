import 'dart:convert';

import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wall_spatial.dart';
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

  test('AI flag, model, and metadata survive a cache JSON round trip', () {
    final FeedItemEntity item = FeedItemEntity.prism(
      id: 'ai-wall',
      wallpaper: PrismWallpaper(
        core: _core('ai-wall', WallpaperSource.prism),
        isAiGenerated: true,
        aiModel: 'Seedream 5 Lite',
        aiMetadata: const <String, Object?>{'prompt': 'a lake'},
      ),
    );

    final PrismFeedItem decoded = decodeFeedItem(_viaJson(item))! as PrismFeedItem;
    expect(decoded.wallpaper.isAiGenerated, isTrue);
    expect(decoded.wallpaper.aiModel, 'Seedream 5 Lite');
    expect(decoded.wallpaper.aiMetadata, <String, Object?>{'prompt': 'a lake'});
  });

  test('the Depth Effect tier survives a JSON round trip, and a wall without one stays unchecked', () {
    for (final WallDepthTier tier in WallDepthTier.values) {
      final item = FeedItemEntity.prism(
        id: 'p1',
        wallpaper: PrismWallpaper(core: _core('p1', WallpaperSource.prism), depthTier: tier),
      );

      expect(
        decodeFeedItem(_viaJson(item)),
        isA<PrismFeedItem>().having((decoded) => decoded.wallpaper.depthTier, 'depthTier', tier),
      );
    }
    final unchecked = FeedItemEntity.prism(
      id: 'p2',
      wallpaper: PrismWallpaper(core: _core('p2', WallpaperSource.prism)),
    );

    expect(
      decodeFeedItem(_viaJson(unchecked)),
      isA<PrismFeedItem>().having((decoded) => decoded.wallpaper.depthTier, 'depthTier', isNull),
    );
    expect(encodeFeedItem(unchecked)['wallpaper'], isNot(contains('depthTier')));
  });

  test('the Spatial Scene tier and map survive a JSON round trip, and a wall without one stays unchecked', () {
    final item = FeedItemEntity.prism(
      id: 'p3',
      wallpaper: PrismWallpaper(
        core: _core('p3', WallpaperSource.prism),
        spatial: const WallSpatial(tier: WallSpatialTier.great, mapUrl: 'https://img.prismwalls.com/spatial/v1/w.png'),
      ),
    );

    expect(
      decodeFeedItem(_viaJson(item)),
      isA<PrismFeedItem>().having(
        (decoded) => decoded.wallpaper.spatial,
        'spatial',
        const WallSpatial(tier: WallSpatialTier.great, mapUrl: 'https://img.prismwalls.com/spatial/v1/w.png'),
      ),
    );
    final unchecked = FeedItemEntity.prism(
      id: 'p4',
      wallpaper: PrismWallpaper(core: _core('p4', WallpaperSource.prism)),
    );

    expect(
      decodeFeedItem(_viaJson(unchecked)),
      isA<PrismFeedItem>().having((decoded) => decoded.wallpaper.spatial, 'spatial', isNull),
    );
    expect(encodeFeedItem(unchecked)['wallpaper'], isNot(contains('spatial')));
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

  test('cached Wallhaven small URLs resolve to lg and are rewritten on save', () {
    const oldCropUrl = 'https://th.wallhaven.cc/small/21/21276x.jpg';
    const originalUrl = 'https://th.wallhaven.cc/lg/21/21276x.jpg';
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

  test('rejects malformed cached field shapes without losing valid neighbours', () {
    final valid = _viaJson(
      FeedItemEntity.prism(
        id: 'valid',
        wallpaper: PrismWallpaper(core: _core('valid', WallpaperSource.prism)),
      ),
    );
    Map<String, dynamic> changed(String key, Object? value, {bool core = false}) {
      final copy = jsonDecode(jsonEncode(valid)) as Map<String, dynamic>;
      final wall = copy['wallpaper'] as Map<String, dynamic>;
      (core ? wall['core'] as Map<String, dynamic> : wall)[key] = value;
      return copy;
    }

    final malformed = <Map<String, dynamic>>[
      changed('core', 'bad'),
      changed('core', <String, dynamic>{}),
      changed('id', <String>['bad'], core: true),
      changed('collections', 'bad'),
      changed('tags', <Object>[<String, Object>{}]),
      changed('review', 'bad'),
      changed('requiredStreakDays', 'bad'),
      changed('width', 'bad', core: true),
      changed('height', double.nan, core: true),
      changed('remixCount', double.infinity),
      changed('source', 'unknown', core: true),
      changed('source', 'pexels', core: true),
      <String, dynamic>{
        ...valid,
        'id': <String>['bad'],
      },
    ];
    final items = <Map<String, dynamic>>[valid, ...malformed, valid].map(decodeFeedItem).nonNulls.toList();
    expect(items.map((item) => item.id), <String>['valid', 'valid']);
  });

  test('rejects malformed provider-specific fields', () {
    for (final entry in <(FeedItemEntity, String, Object)>[
      (
        FeedItemEntity.wallhaven(
          id: 'w',
          wallpaper: WallhavenWallpaper(core: _core('w', WallpaperSource.wallhaven)),
        ),
        'views',
        'bad',
      ),
      (
        FeedItemEntity.wallhaven(
          id: 'w',
          wallpaper: WallhavenWallpaper(core: _core('w', WallpaperSource.wallhaven)),
        ),
        'colors',
        false,
      ),
      (
        FeedItemEntity.pexels(
          id: 'p',
          wallpaper: PexelsWallpaper(core: _core('p', WallpaperSource.pexels)),
        ),
        'src',
        'bad',
      ),
      (
        FeedItemEntity.pexels(
          id: 'p',
          wallpaper: PexelsWallpaper(core: _core('p', WallpaperSource.pexels)),
        ),
        'src',
        <String, Object>{'original': <String>[]},
      ),
    ]) {
      final encoded = _viaJson(entry.$1);
      (encoded['wallpaper'] as Map<String, dynamic>)[entry.$2] = entry.$3;
      expect(decodeFeedItem(encoded), isNull);
    }
  });

  test('legacy wall alias and omitted optional fields decode', () {
    final decoded =
        decodeFeedItem(<String, dynamic>{
              'type': 'prism',
              'id': 'legacy',
              'wall': <String, dynamic>{
                'core': <String, dynamic>{
                  'id': 'legacy',
                  'source': 'wall_of_the_day',
                  'fullUrl': 'full',
                  'thumbnailUrl': 'thumb',
                },
              },
            })
            as PrismFeedItem?;
    expect(decoded, isNotNull);
    expect(decoded!.wallpaper.remixCount, 0);
    expect(decoded.wallpaper.isStreakExclusive, isFalse);
    expect(decoded.wallpaper.collections, isNull);
  });
}
