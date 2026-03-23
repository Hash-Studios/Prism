import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/wallhaven_feed/data/dtos/wallhaven_dtos.dart';

extension WallhavenWallpaperDtoMapper on WallhavenWallpaperDto {
  WallhavenWallpaper toDomain() {
    final String fullUrl = path;
    final String thumbnailUrl =
        thumbs?.large ?? thumbs?.original ?? thumbs?.small ?? fullUrl;
    final String? uploaderUsername = uploader?.username?.trim();
    final bool hasUploader =
        uploaderUsername != null && uploaderUsername.isNotEmpty;

    return WallhavenWallpaper(
      core: WallpaperCore(
        id: id,
        source: WallpaperSource.wallhaven,
        fullUrl: fullUrl,
        thumbnailUrl: thumbnailUrl,
        resolution: resolution.isEmpty ? null : resolution,
        sizeBytes: fileSize,
        authorName: hasUploader ? uploaderUsername : null,
        authorId: hasUploader ? uploaderUsername : null,
        category: category.isEmpty ? null : category,
        favourites: favorites,
      ),
      views: views,
      favorites: favorites,
      dimensionX: dimensionX,
      dimensionY: dimensionY,
      colors: colors.isEmpty ? null : colors,
      thumbs: <String, String>{
        if ((thumbs?.large ?? '').isNotEmpty) 'large': thumbs!.large!,
        if ((thumbs?.original ?? '').isNotEmpty) 'original': thumbs!.original!,
        if ((thumbs?.small ?? '').isNotEmpty) 'small': thumbs!.small!,
      },
      tags: tags
          .map((tag) => tag.name)
          .where((name) => name.isNotEmpty)
          .toList(growable: false),
    );
  }
}
