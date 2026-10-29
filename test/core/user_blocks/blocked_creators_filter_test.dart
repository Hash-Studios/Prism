import 'package:Prism/core/user_blocks/blocked_creators.dart';
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
      expect(BlockedCreatorsFilter.hidesCreatorUid(' uid-1 ', KnownBlockedCreators(<String>{'uid-1'})), isTrue);
      expect(BlockedCreatorsFilter.hidesCreatorUid('UID-1', KnownBlockedCreators(<String>{'uid-1'})), isFalse);
      expect(BlockedCreatorsFilter.hidesCreatorUid(null, KnownBlockedCreators(<String>{'uid-1'})), isFalse);
      expect(BlockedCreatorsFilter.hidesCreatorUid(null, KnownBlockedCreators(<String>{})), isFalse);
    });

    test('hidesFeedItem only hides Prism items with a blocked creator UID', () {
      final BlockedCreators blocked = KnownBlockedCreators(<String>{'uid-1'});
      expect(BlockedCreatorsFilter.hidesFeedItem(_prismItem('1', authorUid: 'uid-1'), blocked), isTrue);
      expect(BlockedCreatorsFilter.hidesFeedItem(_prismItem('2', authorUid: 'other'), blocked), isFalse);
      expect(BlockedCreatorsFilter.hidesFeedItem(_prismItem('3'), blocked), isFalse);
      expect(BlockedCreatorsFilter.hidesFeedItem(_wallhavenItem('3'), blocked), isFalse);
    });

    test('filterFeedItems drops only items from blocked creators', () {
      final BlockedCreators blocked = KnownBlockedCreators(<String>{'uid-1'});
      final items = <FeedItemEntity>[
        _prismItem('1', authorUid: 'uid-1'),
        _prismItem('2', authorUid: 'other'),
        _wallhavenItem('3'),
      ];

      final filtered = BlockedCreatorsFilter.filterFeedItems(items, blocked);

      expect(filtered.map((e) => e.id), <String>['2', '3']);
      expect(BlockedCreatorsFilter.filterFeedItems(items, KnownBlockedCreators(<String>{})), items);
    });
  });

  group('unknown block list', () {
    test('hidesCreatorUid hides any non-empty trimmed creator UID', () {
      expect(BlockedCreatorsFilter.hidesCreatorUid('uid-1', const UnknownBlockedCreators()), isTrue);
      expect(BlockedCreatorsFilter.hidesCreatorUid(null, const UnknownBlockedCreators()), isFalse);
      expect(BlockedCreatorsFilter.hidesCreatorUid('', const UnknownBlockedCreators()), isFalse);
      expect(BlockedCreatorsFilter.hidesCreatorUid('  ', const UnknownBlockedCreators()), isFalse);
    });

    test('hidesFeedItem hides only Prism items that have an author UID', () {
      expect(
        BlockedCreatorsFilter.hidesFeedItem(_prismItem('1', authorUid: 'uid-1'), const UnknownBlockedCreators()),
        isTrue,
      );
      expect(BlockedCreatorsFilter.hidesFeedItem(_prismItem('2'), const UnknownBlockedCreators()), isFalse);
      expect(BlockedCreatorsFilter.hidesFeedItem(_wallhavenItem('3'), const UnknownBlockedCreators()), isFalse);
    });

    test('filterFeedItems keeps the Prism item without an author UID and the Wallhaven item', () {
      final items = <FeedItemEntity>[_prismItem('1', authorUid: 'uid-1'), _prismItem('2'), _wallhavenItem('3')];

      final filtered = BlockedCreatorsFilter.filterFeedItems(items, const UnknownBlockedCreators());

      expect(filtered.map((e) => e.id), <String>['2', '3']);
    });

    test('KnownBlockedCreators compares its UID set by value', () {
      expect(KnownBlockedCreators(<String>{'a', 'b'}) == KnownBlockedCreators(<String>{'b', 'a'}), isTrue);
      expect(KnownBlockedCreators(<String>{'a', 'b'}) != KnownBlockedCreators(<String>{'a'}), isTrue);
    });
  });
}
