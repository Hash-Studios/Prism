import 'package:Prism/core/wallpaper/wall_ai_source.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wall_spatial.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';

final class PrismWallpaper {
  const PrismWallpaper({
    required this.core,
    this.title,
    this.description,
    this.collections,
    this.review,
    this.tags,
    this.colors,
    this.aiMetadata,
    this.isAiGenerated = false,
    this.aiModel,
    this.isStreakExclusive = false,
    this.requiredStreakDays,
    this.streakShopCoinCost,
    this.firestoreDocumentId,
    this.boostedUntil,
    this.depthTier,
    this.spatial,
    this.aiSource,
    this.remixOf,
    this.remixCount = 0,
  });

  final WallpaperCore core;

  /// Name the creator gave the wallpaper on upload. Null for older uploads.
  final String? title;
  final String? description;
  final List<String>? collections;
  final bool? review;
  final List<String>? tags;

  /// Palette ids from `walls.colors`, most dominant first. Null when the wall has none.
  final List<String>? colors;
  final JsonMap? aiMetadata;

  /// `walls.isAiGenerated`. Use `AiContentFilter.isAi`, which also counts walls that carry [aiMetadata].
  final bool isAiGenerated;

  /// Model that made the wall, from `walls.aiModel`. Null when the wall did not record one.
  final String? aiModel;
  final bool isStreakExclusive;
  final int? requiredStreakDays;
  final int? streakShopCoinCost;

  /// Firestore document id in [walls] when loaded from Prism; used for UGC reporting.
  final String? firestoreDocumentId;

  /// End of the paid trending boost. Null when the wall was never boosted.
  final DateTime? boostedUntil;

  /// iOS Depth Effect tier from `walls.depth.tier`. Null when the wall was not checked.
  final WallDepthTier? depthTier;

  /// Spatial Scene tier and depth map from `walls.spatial`. Null when the wall was not checked.
  final WallSpatial? spatial;

  /// The prompt and style of an AI wall. Null on walls that are not AI.
  final WallAiSource? aiSource;

  /// Firestore document id of the wall this one remixes. The server removes a link it cannot verify.
  final String? remixOf;

  /// Approved remixes by other creators. Only the server writes it.
  final int remixCount;

  bool isBoostedAt(DateTime now) => boostedUntil?.isAfter(now) ?? false;

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
