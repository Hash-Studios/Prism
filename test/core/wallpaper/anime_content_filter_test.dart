import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/anime_content_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

WallpaperCore _core(String id, WallpaperSource source) =>
    WallpaperCore(id: id, source: source, fullUrl: 'https://example.com/$id.jpg', thumbnailUrl: 't');

FeedItemEntity _prism(String id, {List<String>? tags}) => PrismFeedItem(
  id: id,
  wallpaper: PrismWallpaper(core: _core(id, WallpaperSource.prism), tags: tags),
);

void main() {
  test('reads the anime setting from the Wallhaven categories flag', () async {
    final settings = SettingsLocalDataSource(InMemoryLocalStore());
    expect(AnimeContentFilter.showsAnime(settings), isFalse);

    await settings.set('WHcategories', 110);
    expect(AnimeContentFilter.showsAnime(settings), isTrue);

    await settings.set('WHcategories', 111);
    expect(AnimeContentFilter.showsAnime(settings), isTrue);

    await settings.set('WHcategories', 100);
    expect(AnimeContentFilter.showsAnime(settings), isFalse);
  });

  test('a Prism wall is anime when its category or a creator tag is anime', () {
    final List<FeedItemEntity> items = <FeedItemEntity>[
      _prism('category', tags: <String>['Anime']),
      _prism('creator-tag', tags: <String>[' anime ']),
      _prism('other', tags: <String>['Nature', 'anime girl']),
      _prism('untagged'),
      WallhavenFeedItem(
        id: 'wh',
        wallpaper: WallhavenWallpaper(core: _core('wh', WallpaperSource.wallhaven)),
      ),
    ];

    expect(AnimeContentFilter.filterFeedItems(items, showAnime: false).map((item) => item.id), <String>[
      'other',
      'untagged',
      'wh',
    ]);
    expect(AnimeContentFilter.filterFeedItems(items, showAnime: true), same(items));
  });
}
