import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';

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
    this.firestoreDocumentId,
  });

  final WallpaperCore core;
  final List<String>? collections;
  final bool? review;
  final List<String>? tags;
  final JsonMap? aiMetadata;
  final bool isStreakExclusive;
  final int? requiredStreakDays;
  final int? streakShopCoinCost;

  /// Firestore document id in [walls] when loaded from Prism; used for UGC reporting.
  final String? firestoreDocumentId;

  String get id => core.id;
  WallpaperSource get source => core.source;
  String get fullUrl => core.fullUrl;
  String get thumbnailUrl => core.thumbnailUrl;
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

  final WallpaperCore core;
  final String? photographer;
  final String? photographerUrl;
  final PexelsSrc? src;

  String get id => core.id;
  WallpaperSource get source => core.source;
  String get fullUrl => core.fullUrl;
  String get thumbnailUrl => core.thumbnailUrl;
}
