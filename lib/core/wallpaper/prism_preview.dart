import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

bool hasPrismPreview(PrismWallpaper wallpaper) {
  if (wallpaper.fullUrl.isNotEmpty) return true;
  final Uri? thumbnail = Uri.tryParse(wallpaper.thumbnailUrl);
  return wallpaper.source == WallpaperSource.prism &&
      wallpaper.id.trim().isNotEmpty &&
      thumbnail != null &&
      thumbnail.scheme == 'https' &&
      thumbnail.host.isNotEmpty;
}
