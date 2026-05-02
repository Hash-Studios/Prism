import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/pexels_feed/data/dtos/pexels_dtos.dart';

extension PexelsPhotoDtoMapper on PexelsPhotoDto {
  PexelsWallpaper toDomain() {
    final PexelsSrc? domainSrc = src == null
        ? null
        : PexelsSrc(
            original: src!.original,
            large2x: src!.large2x,
            large: src!.large,
            medium: src!.medium,
            small: src!.small,
            portrait: src!.portrait,
            landscape: src!.landscape,
            tiny: src!.tiny,
          );

    final String fullUrl = domainSrc?.original.isNotEmpty == true
        ? domainSrc!.original
        : domainSrc?.large2x ?? domainSrc?.large ?? url;

    final String thumbnailUrl = domainSrc?.medium ?? domainSrc?.small ?? domainSrc?.tiny ?? fullUrl;

    final String? resolution = width != null && height != null ? '${width}x$height' : null;

    return PexelsWallpaper(
      core: WallpaperCore(
        id: id.toString(),
        source: WallpaperSource.pexels,
        fullUrl: fullUrl,
        thumbnailUrl: thumbnailUrl,
        resolution: resolution,
        authorName: photographer,
      ),
      photographer: photographer,
      photographerUrl: photographerUrl,
      src: domainSrc,
    );
  }
}
