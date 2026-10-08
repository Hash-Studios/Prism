import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:flutter_test/flutter_test.dart';

WallpaperCore _core(String thumbnailUrl) =>
    WallpaperCore(id: 'x', source: WallpaperSource.wallhaven, fullUrl: 'f', thumbnailUrl: thumbnailUrl);

void main() {
  group('WallpaperCore.thumbnailUrl', () {
    test('keeps wallhaven lg crop unchanged', () {
      expect(
        _core('https://th.wallhaven.cc/lg/21/21276x.jpg').thumbnailUrl,
        'https://th.wallhaven.cc/lg/21/21276x.jpg',
      );
    });

    test('rewrites wallhaven small crop to lg', () {
      expect(
        _core('https://th.wallhaven.cc/small/21/21276x.jpg').thumbnailUrl,
        'https://th.wallhaven.cc/lg/21/21276x.jpg',
      );
    });

    test('keeps wallhaven orig unchanged', () {
      expect(
        _core('https://th.wallhaven.cc/orig/21/21276x.jpg').thumbnailUrl,
        'https://th.wallhaven.cc/orig/21/21276x.jpg',
      );
    });

    test('only rewrites a Wallhaven crop URL path', () {
      expect(
        _core('https://uploads.example/wall.jpg?source=https://th.wallhaven.cc/lg/21/21276x.jpg').thumbnailUrl,
        'https://uploads.example/wall.jpg?source=https://th.wallhaven.cc/lg/21/21276x.jpg',
      );
      expect(
        _core('http://th.wallhaven.cc/small/21/21276x.jpg').thumbnailUrl,
        'http://th.wallhaven.cc/lg/21/21276x.jpg',
      );
      expect(_core('//th.wallhaven.cc/small/21/21276x.jpg').thumbnailUrl, '//th.wallhaven.cc/lg/21/21276x.jpg');
    });

    test('keeps non-wallhaven url unchanged', () {
      expect(
        _core('https://images.pexels.com/photos/1/lg/a.jpg').thumbnailUrl,
        'https://images.pexels.com/photos/1/lg/a.jpg',
      );
    });

    test('keeps empty string unchanged', () {
      expect(_core('').thumbnailUrl, '');
    });
  });

  group('normalizeWallpaperThumbnailUrl', () {
    test('maps Wallhaven small to lg and leaves other URLs unchanged', () {
      expect(
        normalizeWallpaperThumbnailUrl('https://th.wallhaven.cc/lg/21/21276x.jpg'),
        'https://th.wallhaven.cc/lg/21/21276x.jpg',
      );
      expect(
        normalizeWallpaperThumbnailUrl('https://th.wallhaven.cc/small/21/21276x.jpg'),
        'https://th.wallhaven.cc/lg/21/21276x.jpg',
      );
      expect(
        normalizeWallpaperThumbnailUrl('https://images.pexels.com/photos/1/a.jpg'),
        'https://images.pexels.com/photos/1/a.jpg',
      );
      expect(normalizeWallpaperThumbnailUrl(''), '');
    });
  });
}
