import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

sealed class FavouriteWallEntity {
  const FavouriteWallEntity({required this.id, required this.source, this.favouritedAt});

  factory FavouriteWallEntity.fromFeedItem(FeedItemEntity item) => item.when(
    prism: (_, wallpaper) => PrismFavouriteWall(id: wallpaper.id, wallpaper: wallpaper),
    wallhaven: (_, wallpaper) => WallhavenFavouriteWall(id: wallpaper.id, wallpaper: wallpaper),
    pexels: (_, wallpaper) => PexelsFavouriteWall(id: wallpaper.id, wallpaper: wallpaper),
  );

  final String id;
  final WallpaperSource source;

  /// When the user favourited this wall. Null for docs written before this field existed.
  final DateTime? favouritedAt;

  String get thumbnailUrl;
  String get fullUrl;
  DateTime? get createdAt;
  String? get authorName;
  String? get category;

  /// Sort key for "Recently added": the favourite time, else the wall's own date for old docs.
  DateTime? get addedAt => favouritedAt ?? createdAt;

  FeedItemEntity toFeedItem();

  FavouriteWallEntity withFavouritedAt(DateTime at) => switch (this) {
    PrismFavouriteWall(:final wallpaper) => PrismFavouriteWall(id: id, wallpaper: wallpaper, favouritedAt: at),
    WallhavenFavouriteWall(:final wallpaper) => WallhavenFavouriteWall(id: id, wallpaper: wallpaper, favouritedAt: at),
    PexelsFavouriteWall(:final wallpaper) => PexelsFavouriteWall(id: id, wallpaper: wallpaper, favouritedAt: at),
    LegacyFavouriteWall(:final legacyPayload) => LegacyFavouriteWall(
      id: id,
      source: source,
      legacyPayload: legacyPayload,
      favouritedAt: at,
    ),
  };
}

enum FavouriteSort { recentlyAdded, oldest, source }

/// Applies the Favourites screen's sort, source filter and author or category search to [items].
List<FavouriteWallEntity> applyFavouritesView(
  List<FavouriteWallEntity> items, {
  FavouriteSort sort = FavouriteSort.recentlyAdded,
  WallpaperSource? source,
  String query = '',
}) {
  final String needle = query.trim().toLowerCase();
  final List<FavouriteWallEntity> visible = items
      .where((wall) {
        if (source != null && wall.source != source) return false;
        if (needle.isEmpty) return true;
        return (wall.authorName ?? '').toLowerCase().contains(needle) ||
            (wall.category ?? '').toLowerCase().contains(needle);
      })
      .toList(growable: false);
  switch (sort) {
    case FavouriteSort.recentlyAdded:
      return visible..sort(compareByCreatedAtDesc);
    case FavouriteSort.oldest:
      return visible..sort(compareByCreatedAtAsc);
    case FavouriteSort.source:
      return visible..sort((a, b) {
        final int bySource = a.source.index.compareTo(b.source.index);
        return bySource != 0 ? bySource : compareByCreatedAtDesc(a, b);
      });
  }
}

/// Newest [FavouriteWallEntity.addedAt] first; entries without a date go last.
int compareByCreatedAtDesc(FavouriteWallEntity a, FavouriteWallEntity b) {
  final DateTime? aDate = a.addedAt;
  final DateTime? bDate = b.addedAt;
  if (aDate == null && bDate == null) return 0;
  if (aDate == null) return 1;
  if (bDate == null) return -1;
  return bDate.compareTo(aDate);
}

/// Oldest [FavouriteWallEntity.addedAt] first; entries without a date go last.
int compareByCreatedAtAsc(FavouriteWallEntity a, FavouriteWallEntity b) {
  final DateTime? aDate = a.addedAt;
  final DateTime? bDate = b.addedAt;
  if (aDate == null && bDate == null) return 0;
  if (aDate == null) return 1;
  if (bDate == null) return -1;
  return aDate.compareTo(bDate);
}

final class PrismFavouriteWall extends FavouriteWallEntity {
  const PrismFavouriteWall({required super.id, required this.wallpaper, super.favouritedAt})
    : super(source: WallpaperSource.prism);

  final PrismWallpaper wallpaper;

  @override
  String get thumbnailUrl => wallpaper.thumbnailUrl;

  @override
  String get fullUrl => wallpaper.fullUrl;

  @override
  DateTime? get createdAt => wallpaper.core.createdAt;

  @override
  String? get authorName => wallpaper.core.authorName;

  @override
  String? get category => wallpaper.core.category;

  @override
  FeedItemEntity toFeedItem() => PrismFeedItem(id: wallpaper.id, wallpaper: wallpaper);
}

final class WallhavenFavouriteWall extends FavouriteWallEntity {
  const WallhavenFavouriteWall({required super.id, required this.wallpaper, super.favouritedAt})
    : super(source: WallpaperSource.wallhaven);

  final WallhavenWallpaper wallpaper;

  @override
  String get thumbnailUrl => wallpaper.thumbnailUrl;

  @override
  String get fullUrl => wallpaper.fullUrl;

  @override
  DateTime? get createdAt => wallpaper.core.createdAt;

  @override
  String? get authorName => wallpaper.core.authorName;

  @override
  String? get category => wallpaper.core.category;

  @override
  FeedItemEntity toFeedItem() => WallhavenFeedItem(id: wallpaper.id, wallpaper: wallpaper);
}

final class PexelsFavouriteWall extends FavouriteWallEntity {
  const PexelsFavouriteWall({required super.id, required this.wallpaper, super.favouritedAt})
    : super(source: WallpaperSource.pexels);

  final PexelsWallpaper wallpaper;

  @override
  String get thumbnailUrl => wallpaper.thumbnailUrl;

  @override
  String get fullUrl => wallpaper.fullUrl;

  @override
  DateTime? get createdAt => wallpaper.core.createdAt;

  @override
  String? get authorName => wallpaper.core.authorName;

  @override
  String? get category => wallpaper.core.category;

  @override
  FeedItemEntity toFeedItem() => PexelsFeedItem(id: wallpaper.id, wallpaper: wallpaper);
}

/// Used when the existing Firestore doc cannot be resolved to a typed variant
/// (e.g., docs written by older app versions).
final class LegacyFavouriteWall extends FavouriteWallEntity {
  const LegacyFavouriteWall({
    required super.id,
    required super.source,
    required this.legacyPayload,
    super.favouritedAt,
  });

  final JsonMap legacyPayload;

  @override
  String get thumbnailUrl =>
      normalizeWallpaperThumbnailUrl(parseString(firstPresent(legacyPayload, <String>['wallpaper_thumb', 'thumb'])));

  @override
  String get fullUrl => parseString(firstPresent(legacyPayload, <String>['wallpaper_url', 'url']));

  @override
  DateTime? get createdAt => parseDateTime(legacyPayload['createdAt']);

  @override
  String? get authorName => legacyPayload['photographer']?.toString();

  @override
  String? get category => legacyPayload['category']?.toString();

  @override
  FeedItemEntity toFeedItem() => throw ArgumentError('Cannot open a LegacyFavouriteWall as a feed item');
}
