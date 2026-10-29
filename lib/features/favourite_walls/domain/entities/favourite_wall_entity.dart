import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

sealed class FavouriteWallEntity {
  const FavouriteWallEntity({
    required this.id,
    required this.source,
    this.favouritedAt,
    this.syncStatus = FavouriteSyncStatus.synced,
    this.pinnedAt,
  });

  factory FavouriteWallEntity.fromFeedItem(FeedItemEntity item) => item.when(
    prism: (_, wallpaper) => PrismFavouriteWall(id: wallpaper.id, wallpaper: wallpaper),
    wallhaven: (_, wallpaper) => WallhavenFavouriteWall(id: wallpaper.id, wallpaper: wallpaper),
    pexels: (_, wallpaper) => PexelsFavouriteWall(id: wallpaper.id, wallpaper: wallpaper),
  );

  final String id;
  final WallpaperSource source;

  /// When the user saved the wall. Docs written before this field existed have none.
  final DateTime? favouritedAt;
  final FavouriteSyncStatus syncStatus;

  /// When the user pinned the wall to the top of Favourites. Null when it is not pinned.
  final DateTime? pinnedAt;

  bool get pinned => pinnedAt != null;

  String get thumbnailUrl;
  String get fullUrl;
  DateTime? get createdAt;
  String? get authorName;
  String? get category;

  /// Sort key for "Recently added": the favourite time, else the wall's own date for old docs.
  DateTime? get addedAt => favouritedAt ?? createdAt;

  FeedItemEntity toFeedItem();

  FavouriteWallEntity withFavouritedAt(DateTime at) =>
      _with(favouritedAt: at, syncStatus: syncStatus, pinnedAt: pinnedAt);

  FavouriteWallEntity withSyncStatus(FavouriteSyncStatus status) =>
      _with(favouritedAt: favouritedAt, syncStatus: status, pinnedAt: pinnedAt);

  /// [at] null unpins the wall.
  FavouriteWallEntity withPinnedAt(DateTime? at) =>
      _with(favouritedAt: favouritedAt, syncStatus: syncStatus, pinnedAt: at);

  FavouriteWallEntity _with({
    required DateTime? favouritedAt,
    required FavouriteSyncStatus syncStatus,
    required DateTime? pinnedAt,
  }) => switch (this) {
    PrismFavouriteWall(:final wallpaper) => PrismFavouriteWall(
      id: id,
      wallpaper: wallpaper,
      favouritedAt: favouritedAt,
      syncStatus: syncStatus,
      pinnedAt: pinnedAt,
    ),
    WallhavenFavouriteWall(:final wallpaper) => WallhavenFavouriteWall(
      id: id,
      wallpaper: wallpaper,
      favouritedAt: favouritedAt,
      syncStatus: syncStatus,
      pinnedAt: pinnedAt,
    ),
    PexelsFavouriteWall(:final wallpaper) => PexelsFavouriteWall(
      id: id,
      wallpaper: wallpaper,
      favouritedAt: favouritedAt,
      syncStatus: syncStatus,
      pinnedAt: pinnedAt,
    ),
    LegacyFavouriteWall(:final legacyPayload) => LegacyFavouriteWall(
      id: id,
      source: source,
      legacyPayload: legacyPayload,
      favouritedAt: favouritedAt,
      syncStatus: syncStatus,
      pinnedAt: pinnedAt,
    ),
  };
}

/// The most favourites a user can pin to the top of Favourites.
const int maxPinnedFavourites = 12;

enum FavouriteSyncStatus { pending, synced, rejected }

enum FavouriteSort { recentlyAdded, oldest, source }

/// Applies the Favourites screen's sort, source filter and author or category search to [items]. Pinned walls that
/// pass the filter and search show first.
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
  final int Function(FavouriteWallEntity, FavouriteWallEntity) bySort = switch (sort) {
    FavouriteSort.recentlyAdded => compareByCreatedAtDesc,
    FavouriteSort.oldest => compareByCreatedAtAsc,
    FavouriteSort.source => (a, b) {
      final int bySource = a.source.index.compareTo(b.source.index);
      return bySource != 0 ? bySource : compareByCreatedAtDesc(a, b);
    },
  };
  // Pinned walls come first, the first pinned first. The chosen sort orders the rest.
  return visible..sort((a, b) {
    final DateTime? aPin = a.pinnedAt;
    final DateTime? bPin = b.pinnedAt;
    if (aPin != null && bPin != null) return aPin.compareTo(bPin);
    if (aPin != null) return -1;
    if (bPin != null) return 1;
    return bySort(a, b);
  });
}

/// Newest first by the date the wall was saved, else its upload date; entries without a date go last.
int compareByCreatedAtDesc(FavouriteWallEntity a, FavouriteWallEntity b) {
  final DateTime? aDate = a.favouritedAt ?? a.createdAt;
  final DateTime? bDate = b.favouritedAt ?? b.createdAt;
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
  const PrismFavouriteWall({
    required super.id,
    required this.wallpaper,
    super.favouritedAt,
    super.syncStatus,
    super.pinnedAt,
  }) : super(source: WallpaperSource.prism);

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
  const WallhavenFavouriteWall({
    required super.id,
    required this.wallpaper,
    super.favouritedAt,
    super.syncStatus,
    super.pinnedAt,
  }) : super(source: WallpaperSource.wallhaven);

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
  const PexelsFavouriteWall({
    required super.id,
    required this.wallpaper,
    super.favouritedAt,
    super.syncStatus,
    super.pinnedAt,
  }) : super(source: WallpaperSource.pexels);

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
    super.syncStatus,
    super.pinnedAt,
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
