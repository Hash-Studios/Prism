import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';

extension FavouriteWallViewX on FavouriteWallEntity {
  String get provider => source.legacyProviderString;

  String get url => fullUrl;

  String get thumb => thumbnailUrl;

  String get category {
    if (this is PrismFavouriteWall) {
      return (this as PrismFavouriteWall).wallpaper.core.category ?? '';
    }
    if (this is WallhavenFavouriteWall) {
      return (this as WallhavenFavouriteWall).wallpaper.core.category ?? '';
    }
    if (this is PexelsFavouriteWall) {
      return (this as PexelsFavouriteWall).wallpaper.core.category ?? '';
    }
    if (this is LegacyFavouriteWall) {
      return parseString(firstPresent((this as LegacyFavouriteWall).legacyPayload, <String>['category', 'desc']));
    }
    return '';
  }

  String get views {
    if (this is WallhavenFavouriteWall) {
      return (this as WallhavenFavouriteWall).wallpaper.views?.toString() ?? '';
    }
    if (this is LegacyFavouriteWall) {
      return parseString(firstPresent((this as LegacyFavouriteWall).legacyPayload, <String>['views']));
    }
    return '';
  }

  String get fav {
    if (this is WallhavenFavouriteWall) {
      return (this as WallhavenFavouriteWall).wallpaper.favorites?.toString() ?? '';
    }
    if (this is LegacyFavouriteWall) {
      return parseString(firstPresent((this as LegacyFavouriteWall).legacyPayload, <String>['fav', 'favorites']));
    }
    return '';
  }

  String get photographer {
    if (this is PrismFavouriteWall) {
      return (this as PrismFavouriteWall).wallpaper.core.authorName ?? '';
    }
    if (this is PexelsFavouriteWall) {
      return (this as PexelsFavouriteWall).wallpaper.photographer ?? '';
    }
    if (this is LegacyFavouriteWall) {
      return parseString(firstPresent((this as LegacyFavouriteWall).legacyPayload, <String>['photographer', 'by']));
    }
    return '';
  }

  String get resolution {
    if (this is PrismFavouriteWall) {
      return (this as PrismFavouriteWall).wallpaper.core.resolution ?? '';
    }
    if (this is WallhavenFavouriteWall) {
      return (this as WallhavenFavouriteWall).wallpaper.core.resolution ?? '';
    }
    if (this is PexelsFavouriteWall) {
      return (this as PexelsFavouriteWall).wallpaper.core.resolution ?? '';
    }
    if (this is LegacyFavouriteWall) {
      return parseString(firstPresent((this as LegacyFavouriteWall).legacyPayload, <String>['resolution']));
    }
    return '';
  }

  String get size {
    if (this is PrismFavouriteWall) {
      return (this as PrismFavouriteWall).wallpaper.core.sizeBytes?.toString() ?? '';
    }
    if (this is WallhavenFavouriteWall) {
      return (this as WallhavenFavouriteWall).wallpaper.core.sizeBytes?.toString() ?? '';
    }
    if (this is PexelsFavouriteWall) {
      return (this as PexelsFavouriteWall).wallpaper.core.sizeBytes?.toString() ?? '';
    }
    if (this is LegacyFavouriteWall) {
      return parseString(firstPresent((this as LegacyFavouriteWall).legacyPayload, <String>['size']));
    }
    return '';
  }

  List<String> get collections {
    if (this is PrismFavouriteWall) {
      return (this as PrismFavouriteWall).wallpaper.collections ?? const <String>[];
    }
    if (this is WallhavenFavouriteWall) {
      return (this as WallhavenFavouriteWall).wallpaper.tags ?? const <String>[];
    }
    if (this is LegacyFavouriteWall) {
      final raw = (this as LegacyFavouriteWall).legacyPayload['collections'];
      if (raw is List) {
        return raw.map((item) => item?.toString() ?? '').where((item) => item.isNotEmpty).toList(growable: false);
      }
    }
    return const <String>[];
  }
}
