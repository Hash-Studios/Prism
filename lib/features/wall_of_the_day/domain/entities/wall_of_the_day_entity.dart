import 'package:Prism/core/wallpaper/wallpaper_source.dart';

class WallOfTheDayEntity {
  const WallOfTheDayEntity({
    required this.wallId,
    required this.url,
    required this.thumbnailUrl,
    required this.title,
    required this.photographer,
    required this.photographerId,
    required this.date,
    required this.palette,
    required this.isPremium,
    this.source = WallpaperSource.prism,
  });

  /// Resolved wallpaper id (same key as views counter / detail screen), from `walls` data.
  final String wallId;
  final String url;
  final String thumbnailUrl;
  final String title;
  final String photographer;
  final String photographerId;
  final DateTime date;
  final List<String> palette;
  final bool isPremium;

  final WallpaperSource source;
}
