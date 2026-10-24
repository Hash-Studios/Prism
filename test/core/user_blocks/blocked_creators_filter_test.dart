import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:flutter_test/flutter_test.dart';

FeedItemEntity _prismItem(String id, {String? authorUid}) {
  return FeedItemEntity.prism(
    id: id,
    wallpaper: PrismWallpaper(
      core: WallpaperCore(
        id: id,
        source: WallpaperSource.prism,
        fullUrl: 'https://example.com/$id.jpg',
        thumbnailUrl: 'https://example.com/$id-thumb.jpg',
        authorUid: authorUid,
      ),
    ),
  );
}

FeedItemEntity _wallhavenItem(String id) {
  return FeedItemEntity.wallhaven(
    id: id,
    wallpaper: WallhavenWallpaper(
      core: WallpaperCore(
        id: id,
        source: WallpaperSource.wallhaven,
        fullUrl: 'https://example.com/$id.jpg',
        thumbnailUrl: 'https://example.com/$id-thumb.jpg',
      ),
    ),
  );
}

void main() {
  group('BlockedCreatorsFilter', () {
    test('hidesCreatorUid trims but keeps UID case-sensitive', () {
      expect(BlockedCreatorsFilter.hidesCreatorUid(' uid-1 ', <String>{'uid-1'}), isTrue);
      expect(BlockedCreatorsFilter.hidesCreatorUid('UID-1', <String>{'uid-1'}), isFalse);
      expect(BlockedCreatorsFilter.hidesCreatorUid(null, <String>{'uid-1'}), isFalse);
      expect(BlockedCreatorsFilter.hidesCreatorUid(null, <String>{}), isFalse);
    });

    test('hidesFeedItem only hides Prism items with a blocked creator UID', () {
      final Set<String> blocked = <String>{'uid-1'};
      expect(BlockedCreatorsFilter.hidesFeedItem(_prismItem('1', authorUid: 'uid-1'), blocked), isTrue);
      expect(BlockedCreatorsFilter.hidesFeedItem(_prismItem('2', authorUid: 'other'), blocked), isFalse);
      expect(BlockedCreatorsFilter.hidesFeedItem(_prismItem('3'), blocked), isFalse);
      expect(BlockedCreatorsFilter.hidesFeedItem(_wallhavenItem('3'), blocked), isFalse);
    });

    test('filterFeedItems drops only items from blocked creators', () {
      final Set<String> blocked = <String>{'uid-1'};
      final items = <FeedItemEntity>[
        _prismItem('1', authorUid: 'uid-1'),
        _prismItem('2', authorUid: 'other'),
        _wallhavenItem('3'),
      ];

      final filtered = BlockedCreatorsFilter.filterFeedItems(items, blocked);

      expect(filtered.map((e) => e.id), <String>['2', '3']);
      expect(BlockedCreatorsFilter.filterFeedItems(items, <String>{}), items);
    });
  });
}
