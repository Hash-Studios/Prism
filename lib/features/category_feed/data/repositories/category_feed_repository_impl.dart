import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/categories/categories.dart' as category_data;
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/category_feed_page.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/domain/repositories/category_feed_repository.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: CategoryFeedRepository)
class CategoryFeedRepositoryImpl implements CategoryFeedRepository {
  CategoryFeedRepositoryImpl(
    this._settingsLocal,
    this._feedCacheLocal,
    this._prismRepository,
    this._wallhavenRepository,
    this._pexelsRepository,
  );

  final SettingsLocalDataSource _settingsLocal;
  final FeedCacheLocalDataSource _feedCacheLocal;
  final PrismWallpaperRepository _prismRepository;
  final WallhavenWallpaperRepository _wallhavenRepository;
  final PexelsWallpaperRepository _pexelsRepository;

  static const int _feedTtlHours = 6;

  @override
  Future<Result<List<CategoryEntity>>> getCategories() async {
    final categories = category_data.categoryDefinitions
        .map(
          (def) => CategoryEntity(name: def.name, source: def.source, searchType: def.searchType, image: def.imageUrl),
        )
        .toList(growable: false);

    return Result.success(categories);
  }

  @override
  Future<Result<CategoryFeedPage>> fetchCategoryFeed({required CategoryEntity category, required bool refresh}) async {
    final mode = refresh ? 'r' : 'm';
    logger.d(
      '[CategoryFeedRepository] fetchCategoryFeed start',
      fields: <String, Object?>{
        'category': category.name,
        'provider': category.source.legacyProviderString,
        'type': category.searchType.name,
        'refresh': refresh,
      },
    );

    try {
      late final List<FeedItemEntity> items;
      late final bool hasMore;
      switch (category.source) {
        case WallpaperSource.prism:
          final result = await _prismRepository.fetchFeed(refresh: refresh);
          if (result.isFailure || result.data == null) {
            return _cachedOrFailure(
              category: category,
              mode: mode,
              failure: result.failure ?? const UnknownFailure('Failed to fetch Prism feed'),
            );
          }
          final walls = result.data!;
          items = walls.map((wall) => PrismFeedItem(id: wall.id, wallpaper: wall)).toList(growable: false);
          hasMore = _prismRepository.hasMore;

        case WallpaperSource.wallhaven:
          final result = await _wallhavenRepository.fetchFeed(
            categoryName: category.name,
            refresh: refresh,
            categories: _settingsLocal.get<int>('WHcategories', defaultValue: 100),
            purity: _settingsLocal.get<int>('WHpurity', defaultValue: 100),
          );
          if (result.isFailure || result.data == null) {
            return _cachedOrFailure(
              category: category,
              mode: mode,
              failure: result.failure ?? const UnknownFailure('Failed to fetch Wallhaven feed'),
            );
          }
          final walls = result.data!;
          items = walls.map((wall) => WallhavenFeedItem(id: wall.id, wallpaper: wall)).toList(growable: false);
          hasMore = _wallhavenRepository.hasMoreForCategory(category.name);

        case WallpaperSource.pexels:
          final result = await _pexelsRepository.fetchFeed(categoryName: category.name, refresh: refresh);
          if (result.isFailure || result.data == null) {
            return _cachedOrFailure(
              category: category,
              mode: mode,
              failure: result.failure ?? const UnknownFailure('Failed to fetch Pexels feed'),
            );
          }
          final walls = result.data!;
          items = walls.map((wall) => PexelsFeedItem(id: wall.id, wallpaper: wall)).toList(growable: false);
          hasMore = _pexelsRepository.hasMoreForCategory(category.name);

        case WallpaperSource.wallOfTheDay:
        case WallpaperSource.downloaded:
        case WallpaperSource.unknown:
          return Result.error(const ValidationFailure('Unsupported category source'));
      }

      await _writeCache(
        category,
        CategoryFeedPage(items: items, hasMore: hasMore, nextCursor: items.isEmpty ? null : items.length.toString()),
      );

      logger.i(
        '[CategoryFeedRepository] fetchCategoryFeed success',
        fields: <String, Object?>{
          'category': category.name,
          'provider': category.source.legacyProviderString,
          'mode': mode,
          'itemCount': items.length,
          'hasMore': hasMore,
        },
      );

      return Result.success(
        CategoryFeedPage(items: items, hasMore: hasMore, nextCursor: items.isEmpty ? null : items.length.toString()),
      );
    } catch (error, stackTrace) {
      final cached = _readCached(category);
      if (cached != null) {
        logger.w(
          '[CategoryFeedRepository] remote fetch failed; returning cached snapshot',
          error: error,
          stackTrace: stackTrace,
          fields: <String, Object?>{'category': category.name, 'provider': category.source.legacyProviderString},
        );
        return Result.success(cached);
      }

      logger.e(
        '[CategoryFeedRepository] fetchCategoryFeed failed',
        error: error,
        stackTrace: stackTrace,
        fields: <String, Object?>{
          'category': category.name,
          'provider': category.source.legacyProviderString,
          'mode': mode,
        },
      );
      return Result.error(ServerFailure('Failed to fetch category feed: $error'));
    }
  }

  Future<void> _writeCache(CategoryEntity category, CategoryFeedPage page) {
    return _feedCacheLocal.write(
      source: 'category',
      scope: _scopeFor(category),
      ttlHours: _feedTtlHours,
      payload: <String, Object?>{
        'items': page.items.map(_encodeFeedItem).toList(growable: false),
        'hasMore': page.hasMore,
        'nextCursor': page.nextCursor,
      },
    );
  }

  Result<CategoryFeedPage> _cachedOrFailure({
    required CategoryEntity category,
    required String mode,
    required Failure failure,
  }) {
    final cached = _readCached(category);
    if (cached != null) {
      logger.w(
        '[CategoryFeedRepository] provider failed; returning cached snapshot',
        fields: <String, Object?>{
          'category': category.name,
          'provider': category.source.legacyProviderString,
          'mode': mode,
        },
      );
      return Result.success(cached);
    }
    return Result.error(failure);
  }

  CategoryFeedPage? _readCached(CategoryEntity category) {
    final snapshot = _feedCacheLocal.read(source: 'category', scope: _scopeFor(category));
    if (snapshot == null || snapshot.payload is! Map) {
      return null;
    }

    final payload = _asMap(snapshot.payload);
    final rawItems = payload['items'];
    if (rawItems is! List) {
      return null;
    }

    final items = rawItems
        .whereType<Map>()
        .map(_asMap)
        .map(_decodeFeedItem)
        .whereType<FeedItemEntity>()
        .toList(growable: false);

    if (items.isEmpty) {
      return null;
    }

    return CategoryFeedPage(
      items: items,
      hasMore: payload['hasMore'] == true,
      nextCursor: payload['nextCursor']?.toString(),
    );
  }

  String _scopeFor(CategoryEntity category) {
    final normalized = category.name.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');
    return '${category.source.wireValue}.${category.searchType.name}.$normalized';
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map<String, dynamic>((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

Map<String, Object?> _encodeWallpaperCore(WallpaperCore core) {
  return <String, Object?>{
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
}

WallpaperCore _decodeWallpaperCore(Map<String, dynamic> map) {
  return WallpaperCore(
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
}

Map<String, Object?> _encodeFeedItem(FeedItemEntity item) {
  return item.map<Map<String, Object?>>(
    prism: (data) => <String, Object?>{
      'type': 'prism',
      'id': data.id,
      'wallpaper': <String, Object?>{
        'core': _encodeWallpaperCore(data.wallpaper.core),
        'collections': data.wallpaper.collections,
        'review': data.wallpaper.review,
        'tags': data.wallpaper.tags,
        'aiMetadata': data.wallpaper.aiMetadata,
      },
    },
    wallhaven: (data) => <String, Object?>{
      'type': 'wallhaven',
      'id': data.id,
      'wallpaper': <String, Object?>{
        'core': _encodeWallpaperCore(data.wallpaper.core),
        'views': data.wallpaper.views,
        'favorites': data.wallpaper.favorites,
        'dimensionX': data.wallpaper.dimensionX,
        'dimensionY': data.wallpaper.dimensionY,
        'colors': data.wallpaper.colors,
        'thumbs': data.wallpaper.thumbs,
        'tags': data.wallpaper.tags,
        'sizeBytes': data.wallpaper.sizeBytes,
      },
    },
    pexels: (data) => <String, Object?>{
      'type': 'pexels',
      'id': data.id,
      'wallpaper': <String, Object?>{
        'core': _encodeWallpaperCore(data.wallpaper.core),
        'photographer': data.wallpaper.photographer,
        'photographerUrl': data.wallpaper.photographerUrl,
        'src': data.wallpaper.src == null
            ? null
            : <String, Object?>{
                'original': data.wallpaper.src!.original,
                'large2x': data.wallpaper.src!.large2x,
                'large': data.wallpaper.src!.large,
                'medium': data.wallpaper.src!.medium,
                'small': data.wallpaper.src!.small,
                'portrait': data.wallpaper.src!.portrait,
                'landscape': data.wallpaper.src!.landscape,
                'tiny': data.wallpaper.src!.tiny,
              },
      },
    },
  );
}

FeedItemEntity? _decodeFeedItem(Map<String, dynamic> map) {
  final String type = map['type']?.toString() ?? '';
  final String id = map['id']?.toString() ?? '';
  final wallpaperMap = _asMap(map['wallpaper']);
  if (type.isEmpty || id.isEmpty || wallpaperMap.isEmpty) {
    return null;
  }

  switch (type) {
    case 'prism':
      final aiMetadata = _asMap(wallpaperMap['aiMetadata']);
      return PrismFeedItem(
        id: id,
        wallpaper: PrismWallpaper(
          core: _decodeWallpaperCore(_asMap(wallpaperMap['core'])),
          collections: (wallpaperMap['collections'] as List?)?.map((e) => e.toString()).toList(growable: false),
          review: wallpaperMap['review'] as bool?,
          tags: (wallpaperMap['tags'] as List?)?.map((e) => e.toString()).toList(growable: false),
          aiMetadata: aiMetadata.isEmpty ? null : aiMetadata.cast<String, Object?>(),
        ),
      );
    case 'wallhaven':
      final thumbsMap = _asMap(wallpaperMap['thumbs']);
      return WallhavenFeedItem(
        id: id,
        wallpaper: WallhavenWallpaper(
          core: _decodeWallpaperCore(_asMap(wallpaperMap['core'])),
          views: (wallpaperMap['views'] as num?)?.toInt(),
          favorites: (wallpaperMap['favorites'] as num?)?.toInt(),
          dimensionX: (wallpaperMap['dimensionX'] as num?)?.toInt(),
          dimensionY: (wallpaperMap['dimensionY'] as num?)?.toInt(),
          colors: (wallpaperMap['colors'] as List?)?.map((e) => e.toString()).toList(growable: false),
          thumbs: thumbsMap.isEmpty ? null : thumbsMap.map((key, value) => MapEntry(key, value.toString())),
          tags: (wallpaperMap['tags'] as List?)?.map((e) => e.toString()).toList(growable: false),
          sizeBytes: (wallpaperMap['sizeBytes'] as num?)?.toInt(),
        ),
      );
    case 'pexels':
      final srcMap = _asMap(wallpaperMap['src']);
      return PexelsFeedItem(
        id: id,
        wallpaper: PexelsWallpaper(
          core: _decodeWallpaperCore(_asMap(wallpaperMap['core'])),
          photographer: wallpaperMap['photographer']?.toString(),
          photographerUrl: wallpaperMap['photographerUrl']?.toString(),
          src: srcMap.isEmpty
              ? null
              : PexelsSrc(
                  original: srcMap['original']?.toString() ?? '',
                  large2x: srcMap['large2x']?.toString(),
                  large: srcMap['large']?.toString(),
                  medium: srcMap['medium']?.toString(),
                  small: srcMap['small']?.toString(),
                  portrait: srcMap['portrait']?.toString(),
                  landscape: srcMap['landscape']?.toString(),
                  tiny: srcMap['tiny']?.toString(),
                ),
        ),
      );
    default:
      return null;
  }
}
