import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/pexels/model/wallpaperp.dart';
import 'package:Prism/data/wallhaven/model/wallpaper.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/profile_walls/domain/entities/profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';

FavouriteWallEntity? buildFavouriteWallEntityFromLegacy({
  required String? id,
  required String provider,
  required WallPaper? wallhaven,
  required WallPaperP? pexels,
  required Object? prism,
}) {
  final String fallbackId = id?.trim() ?? '';
  final WallpaperSource source = WallpaperSourceX.fromWire(provider);
  if (source == WallpaperSource.wallhaven && wallhaven != null) {
    final String wallId = wallhaven.id?.toString() ?? fallbackId;
    return WallhavenFavouriteWall(
      id: wallId,
      wallpaper: WallhavenWallpaper(
        core: WallpaperCore(
          id: wallId,
          source: WallpaperSource.wallhaven,
          fullUrl: wallhaven.path?.toString() ?? '',
          thumbnailUrl: wallhaven.thumbs?['original']?.toString() ?? wallhaven.path?.toString() ?? '',
          resolution: wallhaven.resolution,
          sizeBytes: int.tryParse(wallhaven.file_size?.toString() ?? ''),
          category: wallhaven.category,
        ),
        views: int.tryParse(wallhaven.views?.toString() ?? ''),
        favorites: int.tryParse(wallhaven.favourites?.toString() ?? ''),
        dimensionX: int.tryParse(wallhaven.dimension_x?.toString() ?? ''),
        dimensionY: int.tryParse(wallhaven.dimension_y?.toString() ?? ''),
      ),
    );
  }

  if (source == WallpaperSource.pexels && pexels != null) {
    final String pexelsId = pexels.id?.toString() ?? fallbackId;
    final String original = pexels.src?['original']?.toString() ?? '';
    final String medium = pexels.src?['medium']?.toString() ?? original;
    return PexelsFavouriteWall(
      id: pexelsId,
      wallpaper: PexelsWallpaper(
        core: WallpaperCore(
          id: pexelsId,
          source: WallpaperSource.pexels,
          fullUrl: original,
          thumbnailUrl: medium,
          resolution: '${pexels.width ?? ''}x${pexels.height ?? ''}',
          authorName: pexels.photographer,
        ),
        photographer: pexels.photographer,
        src: PexelsSrc(original: original, medium: medium),
      ),
    );
  }

  if (source == WallpaperSource.prism && prism != null) {
    final _LegacyPrismPayload payload = _toPrismPayload(prism);
    final String prismId = payload.id.isNotEmpty ? payload.id : fallbackId;
    return PrismFavouriteWall(
      id: prismId,
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: prismId,
          source: WallpaperSource.prism,
          fullUrl: payload.wallpaperUrl,
          thumbnailUrl: payload.wallpaperThumb.isNotEmpty ? payload.wallpaperThumb : payload.wallpaperUrl,
          resolution: payload.resolution,
          sizeBytes: int.tryParse(payload.size),
          authorName: payload.by,
          category: payload.desc,
        ),
        collections: _collections(payload.collections),
      ),
    );
  }

  if (fallbackId.isEmpty) {
    return null;
  }

  return LegacyFavouriteWall(
    id: fallbackId,
    source: source,
    legacyPayload: <String, Object?>{'id': fallbackId, 'provider': provider},
  );
}

List<String>? _collections(Object? raw) {
  if (raw is! List) {
    return null;
  }
  final values = raw.map((item) => item?.toString() ?? '').where((item) => item.isNotEmpty).toList(growable: false);
  return values.isEmpty ? null : values;
}

_LegacyPrismPayload _toPrismPayload(Object prism) {
  if (prism is ProfileWallEntity) {
    return _LegacyPrismPayload(
      id: prism.id,
      by: prism.by ?? '',
      desc: prism.desc ?? '',
      size: prism.size ?? '',
      resolution: prism.resolution ?? '',
      wallpaperThumb: prism.wallpaperThumb ?? '',
      wallpaperUrl: prism.wallpaperUrl,
      collections: prism.collections ?? const <String>[],
    );
  }
  if (prism is PublicProfileWallEntity) {
    return _LegacyPrismPayload(
      id: prism.id,
      by: prism.by ?? '',
      desc: prism.desc ?? '',
      size: prism.size ?? '',
      resolution: prism.resolution ?? '',
      wallpaperThumb: prism.wallpaperThumb ?? '',
      wallpaperUrl: prism.wallpaperUrl,
      collections: prism.collections ?? const <String>[],
    );
  }
  if (prism is Map) {
    return _LegacyPrismPayload(
      id: prism['id']?.toString() ?? '',
      by: prism['by']?.toString() ?? '',
      desc: prism['desc']?.toString() ?? '',
      size: prism['size']?.toString() ?? '',
      resolution: prism['resolution']?.toString() ?? '',
      wallpaperThumb: prism['wallpaper_thumb']?.toString() ?? '',
      wallpaperUrl: prism['wallpaper_url']?.toString() ?? '',
      collections: prism['collections'],
    );
  }
  return const _LegacyPrismPayload();
}

class _LegacyPrismPayload {
  const _LegacyPrismPayload({
    this.id = '',
    this.by = '',
    this.desc = '',
    this.size = '',
    this.resolution = '',
    this.wallpaperThumb = '',
    this.wallpaperUrl = '',
    this.collections,
  });

  final String id;
  final String by;
  final String desc;
  final String size;
  final String resolution;
  final String wallpaperThumb;
  final String wallpaperUrl;
  final Object? collections;
}
