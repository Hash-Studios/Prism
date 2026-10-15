import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

class WallOfTheDayEntity {
  const WallOfTheDayEntity({
    required this.wallId,
    required this.url,
    required this.thumbnailUrl,
    required this.photographer,
    this.source = WallpaperSource.prism,
    this.wallpaper,
  });

  /// Resolved wallpaper id (same key as views counter / detail screen), from `walls` data.
  final String wallId;
  final String url;
  final String thumbnailUrl;
  final String photographer;
  final WallpaperSource source;

  /// The loaded wall, so the detail screen opens with it and needs no second fetch.
  final PrismWallpaper? wallpaper;
}
