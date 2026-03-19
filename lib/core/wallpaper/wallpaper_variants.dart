import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';

final class PrismWallpaper {
  const PrismWallpaper({
    required this.core,
    this.collections,
    this.review,
    this.tags,
    this.aiMetadata,
    this.isStreakExclusive = false,
    this.requiredStreakDays,
    this.streakShopCoinCost,
  });

  final WallpaperCore core;
  final List<String>? collections;
  final bool? review;
  final List<String>? tags;
  final JsonMap? aiMetadata;
  final bool isStreakExclusive;
  final int? requiredStreakDays;
  final int? streakShopCoinCost;

  String get id => core.id;
  WallpaperSource get source => core.source;
  String get fullUrl => core.fullUrl;
  String get thumbnailUrl => core.thumbnailUrl;

  factory PrismWallpaper.fromWotd(WallOfTheDayEntity entity) {
    return PrismWallpaper(
      core: WallpaperCore(
        id: entity.wallId,
        source: WallpaperSource.prism,
        fullUrl: entity.url,
        thumbnailUrl: entity.thumbnailUrl,
        authorName: entity.photographer,
        authorId: entity.photographerId,
        category: entity.title,
        createdAt: entity.date,
      ),
    );
  }
}

final class WallhavenWallpaper {
  const WallhavenWallpaper({
    required this.core,
    this.views,
    this.favorites,
    this.dimensionX,
    this.dimensionY,
    this.colors,
    this.thumbs,
    this.tags,
    this.sizeBytes,
  });

  factory WallhavenWallpaper.fromWotd(WallOfTheDayEntity entity) {
    return WallhavenWallpaper(
      core: WallpaperCore(
        id: entity.wallId,
        source: WallpaperSource.wallhaven,
        fullUrl: entity.url,
        thumbnailUrl: entity.thumbnailUrl,
        authorName: entity.photographer,
        authorId: entity.photographerId,
        category: entity.title,
        createdAt: entity.date,
      ),
    );
  }

  final WallpaperCore core;
  final int? views;
  final int? favorites;
  final int? dimensionX;
  final int? dimensionY;
  final List<String>? colors;
  final Map<String, String>? thumbs;
  final List<String>? tags;
  final int? sizeBytes;

  String get id => core.id;
  WallpaperSource get source => core.source;
  String get fullUrl => core.fullUrl;
  String get thumbnailUrl => core.thumbnailUrl;
}

final class PexelsSrc {
  const PexelsSrc({
    required this.original,
    this.large2x,
    this.large,
    this.medium,
    this.small,
    this.portrait,
    this.landscape,
    this.tiny,
  });

  final String original;
  final String? large2x;
  final String? large;
  final String? medium;
  final String? small;
  final String? portrait;
  final String? landscape;
  final String? tiny;
}

final class PexelsWallpaper {
  const PexelsWallpaper({required this.core, this.photographer, this.photographerUrl, this.src});

  factory PexelsWallpaper.fromWotd(WallOfTheDayEntity entity) {
    return PexelsWallpaper(
      core: WallpaperCore(
        id: entity.wallId,
        source: WallpaperSource.pexels,
        fullUrl: entity.url,
        thumbnailUrl: entity.thumbnailUrl,
        authorName: entity.photographer,
        authorId: entity.photographerId,
        category: entity.title,
        createdAt: entity.date,
      ),
      photographer: entity.photographer,
    );
  }

  final WallpaperCore core;
  final String? photographer;
  final String? photographerUrl;
  final PexelsSrc? src;

  String get id => core.id;
  WallpaperSource get source => core.source;
  String get fullUrl => core.fullUrl;
  String get thumbnailUrl => core.thumbnailUrl;
}
