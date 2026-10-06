import 'dart:ui' show Size;

import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:flutter_test/flutter_test.dart';

FeedItemEntity _prism({List<String>? collections, List<String>? tags, String? author, int? w, int? h, String? res}) =>
    FeedItemEntity.prism(
      id: 'p1',
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: 'p1',
          source: WallpaperSource.prism,
          fullUrl: 'https://img/full.jpg',
          thumbnailUrl: 'https://img/thumb.jpg',
          authorName: author,
          width: w,
          height: h,
          resolution: res,
        ),
        collections: collections,
        tags: tags,
      ),
    );

void main() {
  group('isPremiumFeedItem', () {
    test('is true when a Prism wall sits in a premium collection', () {
      expect(isPremiumFeedItem(_prism(collections: <String>['Gold', 'Nature']), <String>['Gold']), isTrue);
    });

    test('is false for a free collection or no collections', () {
      expect(isPremiumFeedItem(_prism(collections: <String>['Nature']), <String>['Gold']), isFalse);
      expect(isPremiumFeedItem(_prism(), <String>['Gold']), isFalse);
    });

    test('is false for Wallhaven and Pexels walls', () {
      const wallhaven = FeedItemEntity.wallhaven(
        id: 'w',
        wallpaper: WallhavenWallpaper(
          core: WallpaperCore(id: 'w', source: WallpaperSource.wallhaven, fullUrl: 'f', thumbnailUrl: 't'),
        ),
      );
      expect(isPremiumFeedItem(wallhaven, <String>['Gold']), isFalse);
    });
  });

  group('previewCacheWidth', () {
    test('uses screen width in device pixels', () {
      expect(previewCacheWidth(390, 3), 1170);
    });

    test('caps very wide screens at 2160', () {
      expect(previewCacheWidth(1000, 3), 2160);
    });

    test('never returns less than 1', () {
      expect(previewCacheWidth(0, 3), 1);
    });
  });

  group('isLowResolutionForScreen', () {
    const screen = Size(1080, 2400);

    test('flags a wall smaller than the screen', () {
      expect(isLowResolutionForScreen(_prism(w: 720, h: 1280).wallpaperCore, screen), isTrue);
    });

    test('accepts a wall at least as large as the screen, in any orientation', () {
      expect(isLowResolutionForScreen(_prism(w: 3840, h: 2160).wallpaperCore, screen), isFalse);
      expect(isLowResolutionForScreen(_prism(w: 1080, h: 2400).wallpaperCore, screen), isFalse);
    });

    test('reads a resolution string when width and height are missing', () {
      expect(isLowResolutionForScreen(_prism(res: '1280x720').wallpaperCore, screen), isTrue);
      expect(isLowResolutionForScreen(_prism(res: '3840 x 2160').wallpaperCore, screen), isFalse);
    });

    test('does not warn when the size is unknown', () {
      expect(isLowResolutionForScreen(_prism().wallpaperCore, screen), isFalse);
      expect(isLowResolutionForScreen(_prism(res: 'large').wallpaperCore, screen), isFalse);
    });
  });

  group('wallpaperPreviewTitle', () {
    test('uses the creator name when known', () {
      expect(wallpaperPreviewTitle(_prism(author: ' Akshay ')), 'Wallpaper by Akshay');
    });

    test('falls back to a plain title', () {
      expect(wallpaperPreviewTitle(_prism()), 'Wallpaper on Prism');
      expect(wallpaperPreviewTitle(_prism(author: '  ')), 'Wallpaper on Prism');
    });
  });

  group('wallpaperTags', () {
    test('trims, removes duplicates ignoring case, and drops blanks', () {
      expect(wallpaperTags(_prism(tags: <String>[' Space ', 'space', '', 'Stars'])), <String>['Space', 'Stars']);
    });

    test('caps the list at 10', () {
      final tags = List<String>.generate(20, (i) => 'tag$i');
      expect(wallpaperTags(_prism(tags: tags)), hasLength(10));
    });

    test('is empty when a wall has no tags', () {
      expect(wallpaperTags(_prism()), isEmpty);
    });
  });
}
