import 'package:Prism/core/wallpaper/wallpaper_source.dart';

class WallpaperCore {
  const WallpaperCore({
    required this.id,
    required this.source,
    required this.fullUrl,
    required this.thumbnailUrl,
    this.resolution,
    this.sizeBytes,
    this.authorName,
    this.authorEmail,
    this.authorPhoto,
    this.authorId,
    this.category,
    this.createdAt,
    this.width,
    this.height,
    this.favourites,
  });

  final String id;
  final WallpaperSource source;
  final String fullUrl;
  final String thumbnailUrl;
  final String? resolution;
  final int? sizeBytes;
  final String? authorName;
  final String? authorEmail;
  final String? authorPhoto;
  final String? authorId;
  final String? category;
  final DateTime? createdAt;
  final int? width;
  final int? height;
  final int? favourites;
}
