import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';

sealed class WallpaperDetailEntity {
  const WallpaperDetailEntity();

  String get id;
  WallpaperSource get source;
  String get fullUrl;
  String get thumbnailUrl;

  T when<T>({
    required T Function(PrismWallpaper wallpaper) prism,
    required T Function(WallhavenWallpaper wallpaper) wallhaven,
    required T Function(PexelsWallpaper wallpaper) pexels,
  });
}

final class PrismDetailEntity extends WallpaperDetailEntity {
  const PrismDetailEntity({required this.wallpaper});

  final PrismWallpaper wallpaper;

  @override
  String get id => wallpaper.id;

  @override
  WallpaperSource get source => WallpaperSource.prism;

  @override
  String get fullUrl => wallpaper.fullUrl;

  @override
  String get thumbnailUrl => wallpaper.thumbnailUrl;

  @override
  T when<T>({
    required T Function(PrismWallpaper wallpaper) prism,
    required T Function(WallhavenWallpaper wallpaper) wallhaven,
    required T Function(PexelsWallpaper wallpaper) pexels,
  }) {
    return prism(wallpaper);
  }
}

final class WallhavenDetailEntity extends WallpaperDetailEntity {
  const WallhavenDetailEntity({required this.wallpaper});

  final WallhavenWallpaper wallpaper;

  @override
  String get id => wallpaper.id;

  @override
  WallpaperSource get source => WallpaperSource.wallhaven;

  @override
  String get fullUrl => wallpaper.fullUrl;

  @override
  String get thumbnailUrl => wallpaper.thumbnailUrl;

  @override
  T when<T>({
    required T Function(PrismWallpaper wallpaper) prism,
    required T Function(WallhavenWallpaper wallpaper) wallhaven,
    required T Function(PexelsWallpaper wallpaper) pexels,
  }) {
    return wallhaven(wallpaper);
  }
}

final class PexelsDetailEntity extends WallpaperDetailEntity {
  const PexelsDetailEntity({required this.wallpaper});

  final PexelsWallpaper wallpaper;

  @override
  String get id => wallpaper.id;

  @override
  WallpaperSource get source => WallpaperSource.pexels;

  @override
  String get fullUrl => wallpaper.fullUrl;

  @override
  String get thumbnailUrl => wallpaper.thumbnailUrl;

  @override
  T when<T>({
    required T Function(PrismWallpaper wallpaper) prism,
    required T Function(WallhavenWallpaper wallpaper) wallhaven,
    required T Function(PexelsWallpaper wallpaper) pexels,
  }) {
    return pexels(wallpaper);
  }
}

extension WallpaperDetailEntityX on WallpaperDetailEntity {
  static WallpaperDetailEntity fromFavouriteWall(FavouriteWallEntity favourite) {
    return switch (favourite) {
      PrismFavouriteWall(:final wallpaper) => PrismDetailEntity(wallpaper: wallpaper),
      WallhavenFavouriteWall(:final wallpaper) => WallhavenDetailEntity(wallpaper: wallpaper),
      PexelsFavouriteWall(:final wallpaper) => PexelsDetailEntity(wallpaper: wallpaper),
      LegacyFavouriteWall() => throw ArgumentError('Cannot create WallpaperDetailEntity from LegacyFavouriteWall'),
    };
  }

  static WallpaperDetailEntity fromFeedItem(FeedItemEntity item) {
    return item.when(
      prism: (id, wallpaper) => PrismDetailEntity(wallpaper: wallpaper),
      wallhaven: (id, wallpaper) => WallhavenDetailEntity(wallpaper: wallpaper),
      pexels: (id, wallpaper) => PexelsDetailEntity(wallpaper: wallpaper),
    );
  }

  static WallpaperDetailEntity fromPublicProfileWall(PublicProfileWallEntity publicWall) {
    final wallpaper = PrismWallpaper(
      core: WallpaperCore(
        id: publicWall.id,
        source: publicWall.source ?? WallpaperSource.prism,
        fullUrl: publicWall.wallpaperUrl,
        thumbnailUrl: publicWall.wallpaperThumb ?? publicWall.wallpaperUrl,
        resolution: publicWall.resolution,
        sizeBytes: publicWall.size != null ? int.tryParse(publicWall.size!) : null,
        authorName: publicWall.by,
        authorEmail: publicWall.email,
        category: publicWall.desc,
        createdAt: publicWall.createdAt,
      ),
      collections: publicWall.collections,
      review: publicWall.review,
    );
    return PrismDetailEntity(wallpaper: wallpaper);
  }
}
