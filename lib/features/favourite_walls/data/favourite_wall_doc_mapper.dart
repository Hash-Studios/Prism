import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';

FavouriteWallEntity mapFavouriteWallDoc(FavouriteWallDocDto dto, String docId) {
  final String id = dto.id.isNotEmpty ? dto.id : docId;
  final WallpaperSource source = WallpaperSourceX.fromWire(dto.provider);

  switch (source) {
    case WallpaperSource.prism:
      return PrismFavouriteWall(
        id: id,
        favouritedAt: dto.favouritedAt,
        wallpaper: PrismWallpaper(
          core: WallpaperCore(
            id: id,
            source: WallpaperSource.prism,
            fullUrl: dto.url,
            thumbnailUrl: dto.thumb,
            resolution: dto.resolution.isEmpty ? null : dto.resolution,
            sizeBytes: int.tryParse(dto.size),
            authorName: dto.photographer.isEmpty ? null : dto.photographer,
            category: dto.category.isEmpty ? null : dto.category,
            createdAt: dto.createdAt,
          ),
          collections: dto.collections.isEmpty ? null : dto.collections,
          firestoreDocumentId: docId,
        ),
      );
    case WallpaperSource.wallhaven:
      return WallhavenFavouriteWall(
        id: id,
        favouritedAt: dto.favouritedAt,
        wallpaper: WallhavenWallpaper(
          core: WallpaperCore(
            id: id,
            source: WallpaperSource.wallhaven,
            fullUrl: dto.url,
            thumbnailUrl: dto.thumb,
            resolution: dto.resolution.isEmpty ? null : dto.resolution,
            sizeBytes: int.tryParse(dto.size),
            category: dto.category.isEmpty ? null : dto.category,
            createdAt: dto.createdAt,
          ),
          views: int.tryParse(dto.views),
          favorites: int.tryParse(dto.fav),
          tags: dto.collections.isEmpty ? null : dto.collections,
        ),
      );
    case WallpaperSource.pexels:
      return PexelsFavouriteWall(
        id: id,
        favouritedAt: dto.favouritedAt,
        wallpaper: PexelsWallpaper(
          core: WallpaperCore(
            id: id,
            source: WallpaperSource.pexels,
            fullUrl: dto.url,
            thumbnailUrl: dto.thumb,
            resolution: dto.resolution.isEmpty ? null : dto.resolution,
            sizeBytes: int.tryParse(dto.size),
            authorName: dto.photographer.isEmpty ? null : dto.photographer,
            category: dto.category.isEmpty ? null : dto.category,
            createdAt: dto.createdAt,
          ),
          photographer: dto.photographer.isEmpty ? null : dto.photographer,
          src: PexelsSrc(original: dto.url, medium: dto.thumb),
        ),
      );
    case WallpaperSource.downloaded:
    case WallpaperSource.unknown:
      return LegacyFavouriteWall(
        id: id,
        favouritedAt: dto.favouritedAt,
        source: source,
        legacyPayload: <String, Object?>{
          'id': id,
          'provider': dto.provider,
          'url': dto.url,
          'thumb': dto.thumb,
          'category': dto.category,
          'views': dto.views,
          'resolution': dto.resolution,
          'fav': dto.fav,
          'size': dto.size,
          'photographer': dto.photographer,
          'collections': dto.collections,
          'createdAt': dto.createdAt,
        },
      );
  }
}

/// The Firestore doc for a favourite. Every source stores `favouritedAt` so lists sort by when the user saved.
Map<String, dynamic> favouriteWallToDoc(FavouriteWallEntity wall) {
  final DateTime favouritedAt = wall.favouritedAt ?? DateTime.now().toUtc();
  final Map<String, dynamic> doc;
  switch (wall) {
    case PrismFavouriteWall():
      doc = <String, dynamic>{
        'id': wall.id,
        'url': wall.fullUrl,
        'thumb': wall.thumbnailUrl,
        'provider': wall.source.legacyProviderString,
        if (wall.wallpaper.core.category != null) 'category': wall.wallpaper.core.category,
        'views': '',
        if (wall.wallpaper.core.resolution != null) 'resolution': wall.wallpaper.core.resolution,
        'fav': '',
        if (wall.wallpaper.core.sizeBytes != null) 'size': wall.wallpaper.core.sizeBytes.toString(),
        if (wall.wallpaper.core.authorName != null) 'photographer': wall.wallpaper.core.authorName,
        if (wall.wallpaper.collections != null) 'collections': wall.wallpaper.collections,
        'createdAt': wall.createdAt ?? DateTime.now().toUtc(),
        'favouritedAt': favouritedAt,
      };
    case WallhavenFavouriteWall():
      doc = <String, dynamic>{
        'id': wall.id,
        'url': wall.fullUrl,
        'thumb': wall.thumbnailUrl,
        'provider': wall.source.legacyProviderString,
        if (wall.wallpaper.core.category != null) 'category': wall.wallpaper.core.category,
        if (wall.wallpaper.views != null) 'views': wall.wallpaper.views.toString(),
        if (wall.wallpaper.core.resolution != null) 'resolution': wall.wallpaper.core.resolution,
        if (wall.wallpaper.favorites != null) 'fav': wall.wallpaper.favorites.toString(),
        if (wall.wallpaper.core.sizeBytes != null) 'size': wall.wallpaper.core.sizeBytes.toString(),
        'photographer': '',
        if (wall.wallpaper.tags != null) 'collections': wall.wallpaper.tags,
        'createdAt': DateTime.now().toUtc(),
        'favouritedAt': favouritedAt,
      };
    case PexelsFavouriteWall():
      doc = <String, dynamic>{
        'id': wall.id,
        'url': wall.fullUrl,
        'thumb': wall.thumbnailUrl,
        'provider': wall.source.legacyProviderString,
        if (wall.wallpaper.core.category != null) 'category': wall.wallpaper.core.category,
        'views': '',
        if (wall.wallpaper.core.resolution != null) 'resolution': wall.wallpaper.core.resolution,
        'fav': '',
        if (wall.wallpaper.core.sizeBytes != null) 'size': wall.wallpaper.core.sizeBytes.toString(),
        if (wall.wallpaper.photographer != null) 'photographer': wall.wallpaper.photographer,
        'createdAt': DateTime.now().toUtc(),
        'favouritedAt': favouritedAt,
      };
    case LegacyFavouriteWall():
      final Map<String, dynamic> base = Map<String, dynamic>.fromEntries(
        wall.legacyPayload.entries.map((e) => MapEntry<String, dynamic>(e.key, e.value)),
      );
      base['id'] = wall.id;
      base['provider'] = wall.source.legacyProviderString;
      base['createdAt'] ??= DateTime.now().toUtc();
      base['favouritedAt'] = favouritedAt;
      doc = base;
  }
  return doc;
}
