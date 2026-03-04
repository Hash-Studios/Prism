import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

class PexelsWallpaperCodec {
  const PexelsWallpaperCodec();

  PexelsWallpaper fromApiJson(JsonMap photo) {
    final String id = parseString(photo['id']);
    final String photographer = parseString(photo['photographer']);
    final String photographerUrl = parseString(firstPresent(photo, <String>['photographer_url', 'photographerUrl']));
    final int? width = parseInt(photo['width']);
    final int? height = parseInt(photo['height']);

    PexelsSrc? src;
    final Object? srcRaw = photo['src'];
    if (srcRaw is Map) {
      src = PexelsSrc(
        original: parseString(srcRaw['original']),
        large2x: parseString(srcRaw['large2x']) == '' ? null : parseString(srcRaw['large2x']),
        large: parseString(srcRaw['large']) == '' ? null : parseString(srcRaw['large']),
        medium: parseString(srcRaw['medium']) == '' ? null : parseString(srcRaw['medium']),
        small: parseString(srcRaw['small']) == '' ? null : parseString(srcRaw['small']),
        portrait: parseString(srcRaw['portrait']) == '' ? null : parseString(srcRaw['portrait']),
        landscape: parseString(srcRaw['landscape']) == '' ? null : parseString(srcRaw['landscape']),
        tiny: parseString(srcRaw['tiny']) == '' ? null : parseString(srcRaw['tiny']),
      );
    }

    final String fullUrl = src?.original ?? src?.large2x ?? src?.large ?? parseString(photo['url']);
    final String thumbnailUrl = src?.medium ?? src?.small ?? src?.tiny ?? fullUrl;

    final String? resolution = () {
      final int? w = parseInt(photo['width']);
      final int? h = parseInt(photo['height']);
      if (w != null && h != null) return '${w}x$h';
      return null;
    }();

    final WallpaperCore core = WallpaperCore(
      id: id,
      source: WallpaperSource.pexels,
      fullUrl: fullUrl,
      thumbnailUrl: thumbnailUrl,
      resolution: resolution,
      authorName: photographer.isEmpty ? null : photographer,
      authorId: photographerUrl.isEmpty ? null : photographerUrl,
      width: width,
      height: height,
    );

    return PexelsWallpaper(
      core: core,
      photographer: photographer.isEmpty ? null : photographer,
      photographerUrl: photographerUrl.isEmpty ? null : photographerUrl,
      src: src,
    );
  }
}
