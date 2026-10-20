import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/l10n/l10n.dart';

/// What screen readers say for a wallpaper tile in any grid.
String wallpaperSemanticLabel(String? author, AppLocalizations l10n) {
  final String name = author?.trim() ?? '';
  return name.isEmpty ? l10n.coreWallpaperSemanticLabel : l10n.coreWallpaperBySemanticLabel(name);
}

/// Diagnostic label for wallpaper lookup failures. Views choose localized copy from failure type and code.
const String wallpaperLoadFailureMessage = 'Wallpaper lookup failed';

final RegExp _wallhavenCropPath = RegExp('^/(?:lg|small)/');

bool isSafePrismThumbnailUrl(String value) {
  final Uri? uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort && uri.port != 443 ||
      uri.hasQuery ||
      uri.hasFragment) {
    return false;
  }
  final String previewBase = Env.normalize(Env.r2PreviewBaseUrl);
  if (uri.host == 'prismwalls.com' &&
      RegExp(r'^/api/ai/assets/ai/studio/thumb_[A-Za-z0-9_-]+\.jpg$').hasMatch(uri.path)) {
    return true;
  }
  final Uri? base = Uri.tryParse(previewBase);
  if (base != null &&
      base.scheme == 'https' &&
      base.host.isNotEmpty &&
      base.userInfo.isEmpty &&
      !base.hasPort &&
      !base.hasQuery &&
      !base.hasFragment) {
    final String prefix = '${base.path.replaceFirst(RegExp(r'/$'), '')}/previews/';
    if (uri.origin == base.origin &&
        uri.path.startsWith(prefix) &&
        RegExp(r'^[a-f0-9]{64}\.img$').hasMatch(uri.path.substring(prefix.length))) {
      return true;
    }
  }
  if (uri.host != 'raw.githubusercontent.com' ||
      uri.pathSegments.length < 4 ||
      Env.normalize(Env.ghUsername).isEmpty ||
      Env.normalize(Env.ghRepoWalls).isEmpty ||
      uri.pathSegments.any((part) => part.isEmpty || part == '.' || part == '..' || part.contains('/')) ||
      uri.pathSegments[0].toLowerCase() != Env.normalize(Env.ghUsername).toLowerCase() ||
      uri.pathSegments[1] != Env.normalize(Env.ghRepoWalls) ||
      uri.pathSegments.last.isEmpty) {
    return false;
  }
  return uri.pathSegments.last.startsWith('thumb_');
}

String normalizeWallpaperThumbnailUrl(String thumbnailUrl) {
  final Uri? uri = Uri.tryParse(thumbnailUrl);
  if (uri == null) return thumbnailUrl;

  if (uri.host == 'th.wallhaven.cc') {
    final String path = uri.path;
    if (!_wallhavenCropPath.hasMatch(path)) return thumbnailUrl;
    return uri.replace(path: path.replaceFirst(_wallhavenCropPath, '/lg/')).toString();
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
