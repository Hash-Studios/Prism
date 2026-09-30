import 'package:Prism/core/utils/json_utils.dart';
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
      'collections': wall.collections,
      'review': wall.review,
      'tags': wall.tags,
      'aiMetadata': wall.aiMetadata,
      if (wall.firestoreDocumentId != null) 'firestoreDocumentId': wall.firestoreDocumentId,
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
  final String type = map['type']?.toString() ?? '';
  final String id = map['id']?.toString() ?? '';
  final Map<String, dynamic> wallpaper = toJsonMap(map['wallpaper']);
  if (type.isEmpty || id.isEmpty || wallpaper.isEmpty) {
    return null;
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
          core: _decodeCore(toJsonMap(wallpaper['core'])),
          collections: strings(wallpaper['collections']),
          review: wallpaper['review'] as bool?,
          tags: strings(wallpaper['tags']),
          aiMetadata: aiMetadata.isEmpty ? null : aiMetadata.cast<String, Object?>(),
          firestoreDocumentId: (firestoreId != null && firestoreId.isNotEmpty) ? firestoreId : null,
        ),
      );
    case 'wallhaven':
      final Map<String, dynamic> thumbs = toJsonMap(wallpaper['thumbs']);
      return WallhavenFeedItem(
        id: id,
        wallpaper: WallhavenWallpaper(
          core: _decodeCore(toJsonMap(wallpaper['core'])),
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
          core: _decodeCore(toJsonMap(wallpaper['core'])),
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
  authorPhoto: map['authorPhoto']?.toString(),
  authorId: map['authorId']?.toString(),
  category: map['category']?.toString(),
  createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '')?.toUtc(),
  width: (map['width'] as num?)?.toInt(),
  height: (map['height'] as num?)?.toInt(),
  favourites: (map['favourites'] as num?)?.toInt(),
);
