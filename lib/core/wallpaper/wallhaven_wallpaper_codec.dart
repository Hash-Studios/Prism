import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

class WallhavenWallpaperCodec {
  const WallhavenWallpaperCodec();

  WallhavenWallpaper fromApiJson(JsonMap data) {
    final String id = parseString(data['id']);
    final String path = parseString(firstPresent(data, <String>['path', 'url']));
    final String thumbnail = parseString(_extractThumb(data['thumbs']) ?? path);

    final int? views = parseInt(data['views']);
    final int? favorites = parseInt(firstPresent(data, <String>['favorites', 'favourites']));
    final int? dimensionX = parseInt(data['dimension_x']);
    final int? dimensionY = parseInt(data['dimension_y']);
    final String? resolution = parseString(data['resolution']) == '' ? null : parseString(data['resolution']);
    final int? sizeBytes = parseInt(firstPresent(data, <String>['file_size', 'fileSize']));
    final String? category = parseString(data['category']) == '' ? null : parseString(data['category']);
    final int? favourites = parseInt(firstPresent(data, <String>['favorites', 'favourites']));

    List<String>? colors;
    final Object? colorsRaw = data['colors'];
    if (colorsRaw is List) {
      colors = colorsRaw.whereType<Object>().map((Object e) => e.toString()).toList();
    }

    Map<String, String>? thumbs;
    final Object? thumbsRaw = data['thumbs'];
    if (thumbsRaw is Map) {
      thumbs = <String, String>{};
      for (final MapEntry<Object?, Object?> e in thumbsRaw.entries) {
        if (e.value != null) {
          thumbs[e.key.toString()] = e.value.toString();
        }
      }
    }

    List<String>? tags;
    final Object? tagsRaw = data['tags'];
    if (tagsRaw is List) {
      tags = <String>[];
      for (final Object? tag in tagsRaw) {
        if (tag is Map) {
          final String name = parseString(tag['name']);
          if (name.isNotEmpty) tags.add(name);
        } else if (tag != null) {
          tags.add(tag.toString());
        }
      }
    }

    final WallpaperCore core = WallpaperCore(
      id: id,
      source: WallpaperSource.wallhaven,
      fullUrl: path,
      thumbnailUrl: thumbnail,
      resolution: resolution,
      sizeBytes: sizeBytes,
      category: category,
      favourites: favourites,
    );

    return WallhavenWallpaper(
      core: core,
      views: views,
      favorites: favorites,
      dimensionX: dimensionX,
      dimensionY: dimensionY,
      colors: colors,
      thumbs: thumbs,
      tags: tags,
      sizeBytes: sizeBytes,
    );
  }

  String? _extractThumb(Object? thumbsRaw) {
    if (thumbsRaw is Map) {
      final Object? large = thumbsRaw['large'];
      final Object? original = thumbsRaw['original'];
      final Object? small = thumbsRaw['small'];
      return (large ?? original ?? small)?.toString();
    }
    return null;
  }
}
