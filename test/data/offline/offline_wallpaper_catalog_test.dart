import 'dart:io';
import 'dart:async';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('offline-wallpaper-catalog-');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  FeedItemEntity prismItem(String id, {String title = '', List<String>? tags}) => PrismFeedItem(
    id: id,
    wallpaper: PrismWallpaper(
      core: WallpaperCore(
        id: id,
        source: WallpaperSource.prism,
        fullUrl: 'https://example.test/$id.jpg',
        thumbnailUrl: 'https://example.test/$id-thumb.jpg',
      ),
      title: title,
      tags: tags,
    ),
  );

  test('find is source-and-id scoped and survives a catalog restart', () async {
    final first = OfflineWallpaperCatalog(store: DurableJsonStore('catalog', directory: directory));
    await first.remember(<FeedItemEntity>[prismItem('shared', title: 'Night skyline')]);
    await first.remember(<FeedItemEntity>[
      WallhavenFeedItem(
        id: 'shared',
        wallpaper: WallhavenWallpaper(
          core: WallpaperCore(
            id: 'shared',
            source: WallpaperSource.wallhaven,
            fullUrl: 'https://wallhaven.test/shared.jpg',
            thumbnailUrl: 'https://wallhaven.test/thumb.jpg',
          ),
          tags: <String>['mountain'],
        ),
      ),
    ]);

    final restarted = OfflineWallpaperCatalog(store: DurableJsonStore('catalog', directory: directory));

    expect((await restarted.find(WallpaperSource.prism, 'shared'))?.fullUrl, 'https://example.test/shared.jpg');
    expect((await restarted.find(WallpaperSource.wallhaven, 'shared'))?.fullUrl, 'https://wallhaven.test/shared.jpg');
    expect(await restarted.find(WallpaperSource.pexels, 'shared'), isNull);
  });

  test('search covers locally remembered metadata without mixing private records', () async {
    final catalog = OfflineWallpaperCatalog(store: DurableJsonStore('catalog', directory: directory));
    await catalog.remember(<FeedItemEntity>[
      prismItem('one', title: 'Quiet forest', tags: <String>['moss', 'green']),
      prismItem('two', title: 'City lights', tags: <String>['night']),
    ]);

    final matches = await catalog.search('MOSS');

    expect(matches.map((item) => item.id), <String>['one']);
  });

  test('find and search hide Prism items from the current blocked set', () async {
    final OfflineWallpaperCatalog catalog = OfflineWallpaperCatalog(
      store: DurableJsonStore('catalog', directory: directory),
      blockedEmails: () => <String>{'blocked@example.test'},
    );
    final FeedItemEntity blocked = PrismFeedItem(
      id: 'blocked',
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: 'blocked',
          source: WallpaperSource.prism,
          fullUrl: 'https://example.test/blocked.jpg',
          thumbnailUrl: 'https://example.test/blocked-thumb.jpg',
          authorEmail: 'blocked@example.test',
        ),
        title: 'blocked forest',
      ),
    );
    await catalog.remember(<FeedItemEntity>[blocked]);

    expect(await catalog.find(WallpaperSource.prism, 'blocked'), isNull);
    expect(await catalog.search('forest'), isEmpty);
  });

  test('find and search wait for the current block snapshot before exposing catalog items', () async {
    final Completer<Set<String>> blockSnapshot = Completer<Set<String>>();
    final catalog = OfflineWallpaperCatalog(
      store: DurableJsonStore('catalog', directory: directory),
      blockedEmails: () => blockSnapshot.future,
    );
    await catalog.remember(<FeedItemEntity>[
      PrismFeedItem(
        id: 'blocked',
        wallpaper: PrismWallpaper(
          core: WallpaperCore(
            id: 'blocked',
            source: WallpaperSource.prism,
            fullUrl: 'https://example.test/blocked.jpg',
            thumbnailUrl: 'https://example.test/blocked-thumb.jpg',
            authorEmail: 'blocked@example.test',
          ),
          title: 'blocked forest',
        ),
      ),
    ]);

    final Future<FeedItemEntity?> find = catalog.find(WallpaperSource.prism, 'blocked');
    final Future<List<FeedItemEntity>> search = catalog.search('forest');
    await Future<void>.delayed(Duration.zero);
    blockSnapshot.complete(<String>{'blocked@example.test'});

    expect(await find, isNull);
    expect(await search, isEmpty);
  });

  test('the catalog keeps the newest records when the cumulative byte budget is exceeded', () async {
    final store = DurableJsonStore('catalog', directory: directory);
    final catalog = OfflineWallpaperCatalog(store: store);
    await catalog.remember(<FeedItemEntity>[
      prismItem('old', title: 'a' * 700000),
      prismItem('middle', title: 'b' * 700000),
      prismItem('new', title: 'c' * 700000),
    ]);

    final restarted = OfflineWallpaperCatalog(store: DurableJsonStore('catalog', directory: directory));

    expect(await restarted.find(WallpaperSource.prism, 'old'), isNull);
    expect((await restarted.find(WallpaperSource.prism, 'middle'))?.id, 'middle');
    expect((await restarted.find(WallpaperSource.prism, 'new'))?.id, 'new');
  });
}
