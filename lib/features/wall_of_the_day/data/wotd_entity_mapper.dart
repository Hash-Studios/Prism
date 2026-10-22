import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';

WallOfTheDayEntity wallOfTheDayEntityFromPrismWallpaper(
  PrismWallpaper wallpaper, {
  required String wallDocumentId,
  required DateTime featuredAt,
}) {
  final utc = featuredAt.toUtc();
  return WallOfTheDayEntity(
    wallId: wallpaper.id,
    url: wallpaper.fullUrl,
    thumbnailUrl: wallpaper.thumbnailUrl,
    photographer: wallpaper.core.authorName ?? '',
    source: wallpaper.source,
    wallpaper: wallpaper,
    wallDocumentId: wallDocumentId,
    featuredDayUtc: DateTime.utc(utc.year, utc.month, utc.day),
  );
}
