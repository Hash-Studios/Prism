import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/wallpaper/wall_ai_source.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wall_spatial.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

Map<String, Object?> encodeFeedItem(FeedItemEntity item) => item.when(
  prism: (id, wall) => <String, Object?>{
    'type': 'prism',
    'id': id,
    'wallpaper': <String, Object?>{
      'core': _encodeCore(wall.core),
      if (wall.title != null) 'title': wall.title,
      if (wall.description != null) 'description': wall.description,
      'collections': wall.collections,
      'review': wall.review,
      'isStreakExclusive': wall.isStreakExclusive,
      if (wall.requiredStreakDays != null) 'requiredStreakDays': wall.requiredStreakDays,
      if (wall.streakShopCoinCost != null) 'streakShopCoinCost': wall.streakShopCoinCost,
      'tags': wall.tags,
      'aiMetadata': wall.aiMetadata,
      if (wall.isAiGenerated) 'isAiGenerated': true,
      if (wall.aiModel != null) 'aiModel': wall.aiModel,
      if (wall.firestoreDocumentId != null) 'firestoreDocumentId': wall.firestoreDocumentId,
      if (wall.depthTier != null) 'depthTier': wall.depthTier!.name,
      if (wall.spatial != null) 'spatial': wall.spatial!.toJson(),
      if (wall.aiSource != null) 'aiSource': wall.aiSource!.toJson(),
      if (wall.remixOf != null) 'remixOf': wall.remixOf,
      if (wall.remixCount > 0) 'remixCount': wall.remixCount,
    },
  },
  wallhaven: (id, wall) => <String, Object?>{
    'type': 'wallhaven',
    'id': id,
    'wallpaper': <String, Object?>{
      'core': _encodeCore(wall.core),
      'views': wall.views,
      'favorites': wall.favorites,
      'dimensionX': wall.dimensionX,
      'dimensionY': wall.dimensionY,
      'colors': wall.colors,
      'thumbs': wall.thumbs,
      'tags': wall.tags,
      'sizeBytes': wall.sizeBytes,
    },
  },
  pexels: (id, wall) => <String, Object?>{
    'type': 'pexels',
    'id': id,
    'wallpaper': <String, Object?>{
      'core': _encodeCore(wall.core),
      'photographer': wall.photographer,
      'photographerUrl': wall.photographerUrl,
      'src': wall.src == null
          ? null
          : <String, Object?>{
              'original': wall.src!.original,
              'large2x': wall.src!.large2x,
              'large': wall.src!.large,
              'medium': wall.src!.medium,
              'small': wall.src!.small,
              'portrait': wall.src!.portrait,
              'landscape': wall.src!.landscape,
              'tiny': wall.src!.tiny,
            },
    },
  },
);

/// Returns null for entries that are malformed or of an unknown type.
FeedItemEntity? decodeFeedItem(Map<String, dynamic> map) {
  final Object? type = map['type'];
  final Object? id = map['id'];
  final Map<String, dynamic> wallpaper = toJsonMap(map['wallpaper'] ?? map['wall']);
  if (type is! String || id is! String || id.trim().isEmpty || wallpaper.isEmpty) {
    return null;
  }

  final Object? rawCore = wallpaper['core'];
  if (rawCore is! Map) return null;
  final Map<String, dynamic> core = toJsonMap(rawCore);
  if (core['id'] is! String ||
      (core['id'] as String).isEmpty ||
      core['source'] is! String ||
      core['fullUrl'] is! String ||
      core['thumbnailUrl'] is! String) {
    return null;
  }
  final WallpaperSource source = WallpaperSourceX.fromWire(core['source']);
  if (source == WallpaperSource.unknown || source.wireValue != type) return null;

  bool validNumbers(Map<String, dynamic> values, List<String> keys) => keys.every((key) {
    final Object? value = values[key];
    return value == null || value is num && value.isFinite;
  });
  bool validLists(Map<String, dynamic> values, List<String> keys) => keys.every((key) {
    final Object? value = values[key];
    return value == null || value is List && value.every((entry) => entry is String);
  });
  bool validMaps(Map<String, dynamic> values, List<String> keys) =>
      keys.every((key) => values[key] == null || values[key] is Map);
  bool validBools(Map<String, dynamic> values, List<String> keys) =>
      keys.every((key) => values[key] == null || values[key] is bool);
  bool validStringMap(Object? value) =>
      value == null || value is Map && value.values.every((entry) => entry == null || entry is String);

  if (!validNumbers(core, const <String>['sizeBytes', 'width', 'height', 'favourites'])) return null;
  switch (type) {
    case 'prism':
      if (!validLists(wallpaper, const <String>['collections', 'tags']) ||
          !validNumbers(wallpaper, const <String>['requiredStreakDays', 'streakShopCoinCost', 'remixCount']) ||
          !validBools(wallpaper, const <String>['review', 'isStreakExclusive', 'isAiGenerated']) ||
          !validMaps(wallpaper, const <String>['aiMetadata', 'spatial', 'aiSource'])) {
        return null;
      }
    case 'wallhaven':
      if (!validLists(wallpaper, const <String>['colors', 'tags']) ||
          !validNumbers(wallpaper, const <String>['views', 'favorites', 'dimensionX', 'dimensionY', 'sizeBytes']) ||
          !validStringMap(wallpaper['thumbs'])) {
        return null;
      }
    case 'pexels':
      if (!validStringMap(wallpaper['src'])) return null;
  }

  List<String>? strings(Object? value) => (value as List?)?.map((e) => e.toString()).toList(growable: false);
  int? integer(Object? value) => (value as num?)?.toInt();

  switch (type) {
    case 'prism':
      final Map<String, dynamic> aiMetadata = toJsonMap(wallpaper['aiMetadata']);
      final String? firestoreId = wallpaper['firestoreDocumentId']?.toString();
      return PrismFeedItem(
        id: id,
        wallpaper: PrismWallpaper(
          core: _decodeCore(core),
          title: wallpaper['title']?.toString(),
          description: wallpaper['description'] is String ? wallpaper['description'] as String : null,
          collections: strings(wallpaper['collections']),
          review: wallpaper['review'] as bool?,
          isStreakExclusive: wallpaper['isStreakExclusive'] == true,
          requiredStreakDays: integer(wallpaper['requiredStreakDays']),
          streakShopCoinCost: integer(wallpaper['streakShopCoinCost']),
          tags: strings(wallpaper['tags']),
          aiMetadata: aiMetadata.isEmpty ? null : aiMetadata.cast<String, Object?>(),
          isAiGenerated: wallpaper['isAiGenerated'] == true,
          aiModel: wallpaper['aiModel']?.toString(),
          firestoreDocumentId: (firestoreId != null && firestoreId.isNotEmpty) ? firestoreId : null,
          depthTier: WallDepthTier.parse(wallpaper['depthTier']),
          spatial: WallSpatial.parse(wallpaper['spatial']),
          aiSource: WallAiSource.fromJson(wallpaper['aiSource']),
          remixOf: wallpaper['remixOf'] is String ? wallpaper['remixOf'] as String : null,
          remixCount: integer(wallpaper['remixCount']) ?? 0,
        ),
      );
    case 'wallhaven':
      final Map<String, dynamic> thumbs = toJsonMap(wallpaper['thumbs']);
      return WallhavenFeedItem(
        id: id,
        wallpaper: WallhavenWallpaper(
          core: _decodeCore(core),
          views: integer(wallpaper['views']),
          favorites: integer(wallpaper['favorites']),
          dimensionX: integer(wallpaper['dimensionX']),
          dimensionY: integer(wallpaper['dimensionY']),
          colors: strings(wallpaper['colors']),
          thumbs: thumbs.isEmpty ? null : thumbs.map((key, value) => MapEntry(key, value.toString())),
          tags: strings(wallpaper['tags']),
          sizeBytes: integer(wallpaper['sizeBytes']),
        ),
      );
    case 'pexels':
      final Map<String, dynamic> src = toJsonMap(wallpaper['src']);
      return PexelsFeedItem(
        id: id,
        wallpaper: PexelsWallpaper(
          core: _decodeCore(core),
          photographer: wallpaper['photographer']?.toString(),
          photographerUrl: wallpaper['photographerUrl']?.toString(),
          src: src.isEmpty
              ? null
              : PexelsSrc(
                  original: src['original']?.toString() ?? '',
                  large2x: src['large2x']?.toString(),
                  large: src['large']?.toString(),
                  medium: src['medium']?.toString(),
                  small: src['small']?.toString(),
                  portrait: src['portrait']?.toString(),
                  landscape: src['landscape']?.toString(),
                  tiny: src['tiny']?.toString(),
                ),
        ),
      );
    default:
      return null;
  }
}

Map<String, Object?> _encodeCore(WallpaperCore core) => <String, Object?>{
  'id': core.id,
  'source': core.source.wireValue,
  'fullUrl': core.fullUrl,
  'thumbnailUrl': core.thumbnailUrl,
  'resolution': core.resolution,
  'sizeBytes': core.sizeBytes,
  'authorName': core.authorName,
  'authorEmail': core.authorEmail,
  'authorUid': core.authorUid,
  'authorPhoto': core.authorPhoto,
  'authorId': core.authorId,
  'category': core.category,
  'createdAt': core.createdAt?.toUtc().toIso8601String(),
  'width': core.width,
  'height': core.height,
  'favourites': core.favourites,
};

WallpaperCore _decodeCore(Map<String, dynamic> map) => WallpaperCore(
  id: map['id']?.toString() ?? '',
  source: WallpaperSourceX.fromWire(map['source']),
  fullUrl: map['fullUrl']?.toString() ?? '',
  thumbnailUrl: map['thumbnailUrl']?.toString() ?? '',
  resolution: map['resolution']?.toString(),
  sizeBytes: (map['sizeBytes'] as num?)?.toInt(),
  authorName: map['authorName']?.toString(),
  authorEmail: map['authorEmail']?.toString(),
  authorUid: map['authorUid']?.toString(),
  authorPhoto: map['authorPhoto']?.toString(),
  authorId: map['authorId']?.toString(),
  category: map['category']?.toString(),
  createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '')?.toUtc(),
  width: (map['width'] as num?)?.toInt(),
  height: (map['height'] as num?)?.toInt(),
  favourites: (map['favourites'] as num?)?.toInt(),
);
