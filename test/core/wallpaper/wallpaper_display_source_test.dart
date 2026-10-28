import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_display_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const String _previewUrl =
    'https://us-central1-prism-test.cloudfunctions.net/wallpaperPreview?id=p1&thumb=https%3A%2F%2Fimg%2Fthumb.jpg';

FeedItemEntity _prism({
  String id = 'p1',
  String fullUrl = 'https://img/full.jpg',
  String thumbnailUrl = 'https://img/thumb.jpg',
  List<String>? collections,
  bool isStreakExclusive = false,
  int? width,
  int? height,
}) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: fullUrl,
      thumbnailUrl: thumbnailUrl,
      width: width,
      height: height,
    ),
    collections: collections,
    isStreakExclusive: isStreakExclusive,
  ),
);

void main() {
  test('locked Prism wall shows the server preview, never the original', () {
    final display = WallpaperDisplaySource.of(_prism(), projectId: 'prism-test');
    expect(display.full, _previewUrl);
    expect(display.full, isNot(contains('full.jpg')));
    expect(display.thumbnail, 'https://img/thumb.jpg');
  });

  test('unlocked Prism wall still gets the preview URL from the picker', () {
    final display = WallpaperDisplaySource.of(_prism(collections: <String>['Nature']), projectId: 'prism-test');
    expect(display.full, _previewUrl);
    expect(display.full, isNot('https://img/full.jpg'));
  });

  test('premium Prism wall gets the preview URL, not the original', () {
    final display = WallpaperDisplaySource.of(_prism(collections: <String>['premium']), projectId: 'prism-test');
    expect(display.full, _previewUrl);
    expect(display.full, isNot('https://img/full.jpg'));
  });

  test('streak-exclusive Prism wall is withheld: no full image, thumbnail is the best link', () {
    final display = WallpaperDisplaySource.of(_prism(isStreakExclusive: true), projectId: 'prism-test');
    expect(display.full, '');
    expect(display.bestLink, 'https://img/thumb.jpg');
  });

  test('drop wall withheld: no full image', () {
    final display = WallpaperDisplaySource.forWall(
      id: 'd1',
      source: WallpaperSource.prism,
      thumbnail: 'https://img/d.jpg',
      withheld: true,
      projectId: 'prism-test',
    );
    expect(display.full, '');
  });

  test('Prism wall without a project id gets no preview and falls back to the thumbnail', () {
    final display = WallpaperDisplaySource.of(_prism(), projectId: '');
    expect(display.full, '');
    expect(display.bestLink, display.thumbnail);
    expect(display.bestLink, 'https://img/thumb.jpg');
  });

  test('Wallhaven wall keeps its public original', () {
    const entity = FeedItemEntity.wallhaven(
      id: 'w1',
      wallpaper: WallhavenWallpaper(
        core: WallpaperCore(
          id: 'w1',
          source: WallpaperSource.wallhaven,
          fullUrl: 'https://w.wallhaven.cc/full/ab/wallhaven-ab1234.jpg',
          thumbnailUrl: 'https://th.wallhaven.cc/small/ab/ab1234.jpg',
        ),
      ),
    );
    final display = WallpaperDisplaySource.of(entity, projectId: 'prism-test');
    expect(display.full, 'https://w.wallhaven.cc/full/ab/wallhaven-ab1234.jpg');
  });

  test('Pexels wall keeps its public original', () {
    const entity = FeedItemEntity.pexels(
      id: 'x1',
      wallpaper: PexelsWallpaper(
        core: WallpaperCore(
          id: 'x1',
          source: WallpaperSource.pexels,
          fullUrl: 'https://images.pexels.com/photos/1/pexels-photo-1.jpeg',
          thumbnailUrl: 'https://images.pexels.com/photos/1/pexels-photo-1.jpeg?w=400',
        ),
      ),
    );
    final display = WallpaperDisplaySource.of(entity, projectId: 'prism-test');
    expect(display.full, 'https://images.pexels.com/photos/1/pexels-photo-1.jpeg');
  });

  test('bundled starter uses its local file', () {
    final display = WallpaperDisplaySource.forWall(
      id: 'starter-prism',
      source: WallpaperSource.prism,
      thumbnail: '/data/starter.jpg',
      fullUrl: '/data/starter.jpg',
      projectId: 'prism-test',
    );
    expect(display.full, '/data/starter.jpg');
  });

  test('a non-starter feed field never opens a local file', () {
    final display = WallpaperDisplaySource.forWall(
      id: 'w2',
      source: WallpaperSource.wallhaven,
      thumbnail: 'https://th.wallhaven.cc/small/ab/ab1234.jpg',
      fullUrl: '/etc/passwd',
      projectId: 'prism-test',
    );
    expect(display.full, '');
  });

  test('Prism wall with no thumbnail has no preview and no best link', () {
    final display = WallpaperDisplaySource.of(_prism(thumbnailUrl: ''), projectId: 'prism-test');
    expect(display.thumbnail, '');
    expect(display.full, '');
    expect(display.bestLink, '');
  });

  test('pixel size comes from the wall width and height', () {
    final display = WallpaperDisplaySource.of(_prism(width: 1440, height: 3200), projectId: 'prism-test');
    expect(display.pixelSize, const Size(1440, 3200));
  });

  group('sizedWallpaperImage', () {
    const ImageProvider image = AssetImage('assets/wall.jpg');
    ResizeImage sized(Size box, Size? wall) => sizedWallpaperImage(image, box, 3, wall) as ResizeImage;

    test('an unknown size decodes the wall whole, within 4096 on each side', () {
      final ResizeImage resized = sized(const Size(390, 844), null);
      expect((resized.width, resized.height, resized.policy), (4096, 4096, ResizeImagePolicy.fit));
      expect(resized.imageProvider, image);
    });

    test('a portrait wall in a portrait box follows the box width', () {
      final ResizeImage resized = sized(const Size(390, 844), const Size(1440, 3200));
      expect((resized.width, resized.height), (1170, null));
    });

    test('a landscape 4K wall in a portrait box follows the box height and is never enlarged', () {
      final ResizeImage resized = sized(const Size(390, 844), const Size(3840, 2160));
      expect((resized.width, resized.height), (null, 2160));
    });

    test('an 8K wall is capped at 4096 on its long side', () {
      final ResizeImage resized = sized(const Size(2000, 1000), const Size(7680, 4320));
      expect((resized.width, resized.height), (4096, null));
    });
  });
}
