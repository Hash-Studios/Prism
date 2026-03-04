import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

sealed class FavouriteWallEntity {
  const FavouriteWallEntity({required this.id, required this.source});

  final String id;
  final WallpaperSource source;

  String get thumbnailUrl;
  String get fullUrl;
  DateTime? get createdAt;
}

final class PrismFavouriteWall extends FavouriteWallEntity {
  const PrismFavouriteWall({required super.id, required this.wallpaper}) : super(source: WallpaperSource.prism);

  final PrismWallpaper wallpaper;

  @override
  String get thumbnailUrl => wallpaper.thumbnailUrl;

  @override
  String get fullUrl => wallpaper.fullUrl;

  @override
  DateTime? get createdAt => wallpaper.core.createdAt;
}

final class WallhavenFavouriteWall extends FavouriteWallEntity {
  const WallhavenFavouriteWall({required super.id, required this.wallpaper}) : super(source: WallpaperSource.wallhaven);

  final WallhavenWallpaper wallpaper;

  @override
  String get thumbnailUrl => wallpaper.thumbnailUrl;

  @override
  String get fullUrl => wallpaper.fullUrl;

  @override
  DateTime? get createdAt => null;
}

final class PexelsFavouriteWall extends FavouriteWallEntity {
  const PexelsFavouriteWall({required super.id, required this.wallpaper}) : super(source: WallpaperSource.pexels);

  final PexelsWallpaper wallpaper;

  @override
  String get thumbnailUrl => wallpaper.thumbnailUrl;

  @override
  String get fullUrl => wallpaper.fullUrl;

  @override
  DateTime? get createdAt => null;
}

/// Used when the existing Firestore doc cannot be resolved to a typed variant
/// (e.g., docs written by older app versions).
final class LegacyFavouriteWall extends FavouriteWallEntity {
  const LegacyFavouriteWall({required super.id, required super.source, required this.legacyPayload});

  final JsonMap legacyPayload;

  @override
  String get thumbnailUrl => parseString(firstPresent(legacyPayload, <String>['wallpaper_thumb', 'thumb']));

  @override
  String get fullUrl => parseString(firstPresent(legacyPayload, <String>['wallpaper_url', 'url']));

  @override
  DateTime? get createdAt => parseDateTime(legacyPayload['createdAt']);
}
