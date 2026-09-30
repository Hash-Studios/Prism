import 'package:Prism/core/wallpaper/wallpaper_source.dart';

/// What screen readers say for a wallpaper tile in any grid.
String wallpaperSemanticLabel(String? author) {
  final String name = author?.trim() ?? '';
  return name.isEmpty ? 'Wallpaper' : 'Wallpaper by $name';
}

final RegExp _wallhavenCropPath = RegExp('^/(?:lg|small)/');

String normalizeWallpaperThumbnailUrl(String thumbnailUrl) {
  final Uri? uri = Uri.tryParse(thumbnailUrl);
  if (uri == null) return thumbnailUrl;

  if (uri.host == 'th.wallhaven.cc') {
    final String path = uri.path;
    if (!_wallhavenCropPath.hasMatch(path)) return thumbnailUrl;
    return uri.replace(path: path.replaceFirst(_wallhavenCropPath, '/orig/')).toString();
  }

  if (uri.host == 'images.pexels.com') {
    try {
      final Map<String, String> query = uri.queryParameters;
      if (query['fit'] != 'crop' || !query.containsKey('w') || !query.containsKey('h')) return thumbnailUrl;
      return uri.replace(queryParameters: <String, String>{...query, 'fit': 'max'}).toString();
    } on FormatException {
      return thumbnailUrl;
    }
  }

  return thumbnailUrl;
}

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

  /// Wallhaven lg/small and Pexels tiny variants crop the original aspect ratio.
  String get thumbnailUrl => normalizeWallpaperThumbnailUrl(_thumbnailUrl);

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
