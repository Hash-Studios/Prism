import 'package:Prism/core/wallpaper/wallpaper_source.dart';

class WallpaperHandle {
  const WallpaperHandle({required this.id, required this.source, required this.thumbnailUrl, this.fullUrl});

  final String id;
  final WallpaperSource source;
  final String thumbnailUrl;
  final String? fullUrl;
}
