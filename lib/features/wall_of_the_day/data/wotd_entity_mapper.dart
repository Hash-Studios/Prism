import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';

WallOfTheDayEntity wallOfTheDayEntityFromPrismWallpaper(PrismWallpaper wallpaper, DateTime featuredAt) {
  return WallOfTheDayEntity(
    wallId: wallpaper.id,
    url: wallpaper.fullUrl,
    thumbnailUrl: wallpaper.thumbnailUrl,
    title: wallpaper.core.category ?? '',
    photographer: wallpaper.core.authorName ?? '',
    photographerId: wallpaper.core.authorEmail ?? '',
    date: featuredAt,
    palette: const <String>[],
    isPremium: false,
    source: wallpaper.source,
  );
}
