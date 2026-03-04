import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';

final class PrismWallpaperView {
  const PrismWallpaperView({
    required this.id,
    required this.desc,
    required this.size,
    required this.email,
    required this.userPhoto,
    required this.by,
    required this.resolution,
    required this.wallpaperUrl,
    required this.wallpaperThumb,
    required this.collections,
  });

  final String id;
  final String desc;
  final String size;
  final String email;
  final String userPhoto;
  final String by;
  final String resolution;
  final String wallpaperUrl;
  final String wallpaperThumb;
  final List<String> collections;

  factory PrismWallpaperView.fromTyped(PrismWallpaper wallpaper) {
    return PrismWallpaperView(
      id: wallpaper.id,
      desc: wallpaper.core.category ?? '',
      size: wallpaper.core.sizeBytes?.toString() ?? '',
      email: '',
      userPhoto: '',
      by: wallpaper.core.authorName ?? '',
      resolution: wallpaper.core.resolution ?? '',
      wallpaperUrl: wallpaper.fullUrl,
      wallpaperThumb: wallpaper.thumbnailUrl,
      collections: wallpaper.collections ?? const <String>[],
    );
  }

  factory PrismWallpaperView.fromWotd(WallOfTheDayEntity entity) {
    return PrismWallpaperView(
      id: entity.wallId,
      desc: entity.title,
      size: '',
      email: entity.photographerId,
      userPhoto: '',
      by: entity.photographer,
      resolution: '',
      wallpaperUrl: entity.url,
      wallpaperThumb: entity.thumbnailUrl,
      collections: const <String>[],
    );
  }

  factory PrismWallpaperView.fromLegacyMap(Map<String, dynamic> raw) {
    return PrismWallpaperView(
      id: parseString(raw['id']),
      desc: parseString(raw['desc']),
      size: parseString(raw['size']),
      email: parseString(raw['email']),
      userPhoto: parseString(raw['userPhoto']),
      by: parseString(raw['by']),
      resolution: parseString(raw['resolution']),
      wallpaperUrl: parseString(raw['wallpaper_url']),
      wallpaperThumb: parseString(raw['wallpaper_thumb']),
      collections: parseStringList(raw['collections']),
    );
  }
}
