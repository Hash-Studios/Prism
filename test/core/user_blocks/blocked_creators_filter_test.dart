import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:flutter_test/flutter_test.dart';

FeedItemEntity _prismItem(String id, {String? authorEmail}) {
  return FeedItemEntity.prism(
    id: id,
    wallpaper: PrismWallpaper(
      core: WallpaperCore(
        id: id,
        source: WallpaperSource.prism,
        fullUrl: 'https://example.com/$id.jpg',
        thumbnailUrl: 'https://example.com/$id-thumb.jpg',
        authorEmail: authorEmail,
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
    test('normalizeEmail lowercases and trims', () {
      expect(BlockedCreatorsFilter.normalizeEmail('  A@B.COM '), 'a@b.com');
      expect(BlockedCreatorsFilter.normalizeEmail(null), '');
    });

    test('hidesCreatorEmail respects blocked set', () {
      final Set<String> blocked = <String>{'a@b.com'};
      expect(BlockedCreatorsFilter.hidesCreatorEmail('A@B.COM', blocked), isTrue);
      expect(BlockedCreatorsFilter.hidesCreatorEmail('other@test.com', blocked), isFalse);
      expect(BlockedCreatorsFilter.hidesCreatorEmail('', blocked), isFalse);
      expect(BlockedCreatorsFilter.hidesCreatorEmail('a@b.com', <String>{}), isFalse);
    });

    test('hidesFeedItem only hides Prism items with a blocked creator email', () {
      final Set<String> blocked = <String>{'a@b.com'};
      expect(BlockedCreatorsFilter.hidesFeedItem(_prismItem('1', authorEmail: 'a@b.com'), blocked), isTrue);
      expect(BlockedCreatorsFilter.hidesFeedItem(_prismItem('2', authorEmail: 'other@test.com'), blocked), isFalse);
      // Non-Prism sources never carry a blockable creator email.
      expect(BlockedCreatorsFilter.hidesFeedItem(_wallhavenItem('3'), blocked), isFalse);
    });

    test('filterFeedItems drops only items from blocked creators', () {
      final Set<String> blocked = <String>{'a@b.com'};
      final items = <FeedItemEntity>[
        _prismItem('1', authorEmail: 'a@b.com'),
        _prismItem('2', authorEmail: 'other@test.com'),
        _wallhavenItem('3'),
      ];

      final filtered = BlockedCreatorsFilter.filterFeedItems(items, blocked);

      expect(filtered.map((e) => e.id), <String>['2', '3']);
      expect(BlockedCreatorsFilter.filterFeedItems(items, <String>{}), items);
    });
  });
}
