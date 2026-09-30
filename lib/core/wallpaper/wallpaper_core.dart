import 'package:Prism/core/wallpaper/wallpaper_source.dart';

/// What screen readers say for a wallpaper tile in any grid.
String wallpaperSemanticLabel(String? author) {
  final String name = author?.trim() ?? '';
  return name.isEmpty ? 'Wallpaper' : 'Wallpaper by $name';
}

final RegExp _wallhavenCropThumb = RegExp(r'//th\.wallhaven\.cc/(?:lg|small)/');

class WallpaperCore {
  const WallpaperCore({
    required this.id,
    required this.source,
    required this.fullUrl,
    required String thumbnailUrl,
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
  }) : _thumbnailUrl = thumbnailUrl;

  final String id;
  final WallpaperSource source;
  final String fullUrl;
  final String _thumbnailUrl;

  /// Wallhaven lg/small thumbs are landscape crops; orig keeps the aspect ratio.
  String get thumbnailUrl => _thumbnailUrl.replaceFirst(_wallhavenCropThumb, '//th.wallhaven.cc/orig/');

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
