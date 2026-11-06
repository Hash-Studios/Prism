import 'package:Prism/core/wallpaper/placeholder_color.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const Color _white = Color(0xFFFFFFFF);

WallpaperCore _core(WallpaperSource source) =>
    WallpaperCore(id: 'w', source: source, fullUrl: 'https://x/f.jpg', thumbnailUrl: 'https://x/t.jpg');

FeedItemEntity _prism(List<String>? colors) => FeedItemEntity.prism(
  id: 'w',
  wallpaper: PrismWallpaper(core: _core(WallpaperSource.prism), colors: colors),
);

FeedItemEntity _wallhaven(List<String>? colors) => FeedItemEntity.wallhaven(
  id: 'w',
  wallpaper: WallhavenWallpaper(core: _core(WallpaperSource.wallhaven), colors: colors),
);

void main() {
  test('a Prism wall uses its first palette colour, a quarter of the way to the surface', () {
    // Red is cc0000. 25 % toward white: 0xcc + 0x33 / 4 = 216.75, so 0xd9; 0 + 0xff / 4 = 63.75, so 0x40.
    final Color colour = placeholderColorOf(_prism(const <String>['red', 'blue']), _white)!;
    expect(colour.toARGB32(), 0xFFD94040);
  });

  test('a Wallhaven wall reads its first hex colour, with or without #', () {
    expect(placeholderColorOf(_wallhaven(const <String>['#000000']), _white)!.toARGB32(), 0xFF404040);
    expect(placeholderColorOf(_wallhaven(const <String>['000000']), _white)!.toARGB32(), 0xFF404040);
  });

  test('the mute keeps the hue on a dark surface', () {
    final Color colour = placeholderColorOf(_prism(const <String>['blue']), const Color(0xFF000000))!;
    expect(HSVColor.fromColor(colour).hue, closeTo(HSVColor.fromColor(const Color(0xFF0066CC)).hue, 1));
  });

  test('no colour, an unknown palette id, a bad hex or a Pexels wall gives null', () {
    expect(placeholderColorOf(_prism(null), _white), isNull);
    expect(placeholderColorOf(_prism(const <String>[]), _white), isNull);
    expect(placeholderColorOf(_prism(const <String>['mauve']), _white), isNull);
    expect(placeholderColorOf(_wallhaven(const <String>['#12345']), _white), isNull);
    expect(placeholderColorOf(_wallhaven(const <String>['-12345']), _white), isNull);
    expect(
      placeholderColorOf(
        FeedItemEntity.pexels(
          id: 'w',
          wallpaper: PexelsWallpaper(core: _core(WallpaperSource.pexels)),
        ),
        _white,
      ),
      isNull,
    );
  });
}
