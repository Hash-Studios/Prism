import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:flutter_test/flutter_test.dart';

WallpaperCore _core(String thumbnailUrl) =>
    WallpaperCore(id: 'x', source: WallpaperSource.wallhaven, fullUrl: 'f', thumbnailUrl: thumbnailUrl);

void main() {
  group('WallpaperCore.thumbnailUrl', () {
    test('rewrites wallhaven lg crop to orig', () {
      expect(
        _core('https://th.wallhaven.cc/lg/21/21276x.jpg').thumbnailUrl,
        'https://th.wallhaven.cc/orig/21/21276x.jpg',
      );
    });

    test('rewrites wallhaven small crop to orig', () {
      expect(
        _core('https://th.wallhaven.cc/small/21/21276x.jpg').thumbnailUrl,
        'https://th.wallhaven.cc/orig/21/21276x.jpg',
      );
    });

    test('keeps wallhaven orig unchanged', () {
      expect(
        _core('https://th.wallhaven.cc/orig/21/21276x.jpg').thumbnailUrl,
        'https://th.wallhaven.cc/orig/21/21276x.jpg',
      );
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
}
