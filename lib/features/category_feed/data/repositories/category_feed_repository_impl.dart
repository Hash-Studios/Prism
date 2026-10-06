import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/categories/categories.dart' as category_data;
import 'package:Prism/data/feed_cache/paged_feed_cache.dart';
import 'package:Prism/features/category_feed/data/feed_item_cache_codec.dart';
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
          (def) => CategoryEntity(
            name: def.name,
            source: def.source,
            searchType: def.searchType,
            image: def.imageUrl,
            image2: def.secondaryImageUrl,
          ),
        )
        .toList(growable: false);

    return Result.success(categories);
  }

  @override
  Future<Result<CategoryFeedPage>> fetchCategoryFeed({required CategoryEntity category, required bool refresh}) async {
    final mode = refresh ? 'r' : 'm';

    try {
      final fetched = await _fetchFromSource(category, refresh: refresh);
      final page = fetched.data;
      if (page == null) {
        final failure = fetched.failure ?? const UnknownFailure('Failed to fetch feed');
        if (!refresh) {
          return Result.error(failure);
        }
        return await _cachedOrFailure(category: category, mode: mode, failure: failure);
      }

      if (refresh) {
        await _writeCache(category, page);
      }

      logger.i(
        '[CategoryFeedRepository] fetchCategoryFeed success',
        fields: <String, Object?>{
          'category': category.name,
          'provider': category.source.legacyProviderString,
          'mode': mode,
          'itemCount': page.items.length,
          'hasMore': page.hasMore,
        },
      );

      return Result.success(page);
    } catch (error, stackTrace) {
      final cached = refresh ? await _readCached(category) : null;
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

  Future<Result<CategoryFeedPage>> _fetchFromSource(CategoryEntity category, {required bool refresh}) async {
    switch (category.source) {
      case WallpaperSource.prism:
        final result = await _prismRepository.fetchFeed(refresh: refresh);
        return _toPage(
          result,
          label: 'Prism',
          toItem: (wall) => PrismFeedItem(id: wall.id, wallpaper: wall),
          hasMore: _prismRepository.hasMore,
        );
      case WallpaperSource.wallhaven:
        final result = await _wallhavenRepository.fetchFeed(
          categoryName: category.name,
          refresh: refresh,
          categories: _settingsLocal.get<int>('WHcategories', defaultValue: 100),
          purity: _settingsLocal.get<int>('WHpurity', defaultValue: 100),
        );
        return _toPage(
          result,
          label: 'Wallhaven',
          toItem: (wall) => WallhavenFeedItem(id: wall.id, wallpaper: wall),
          hasMore: _wallhavenRepository.hasMoreForCategory(category.name),
        );
      case WallpaperSource.pexels:
        final result = await _pexelsRepository.fetchFeed(categoryName: category.name, refresh: refresh);
        return _toPage(
          result,
          label: 'Pexels',
          toItem: (wall) => PexelsFeedItem(id: wall.id, wallpaper: wall),
          hasMore: _pexelsRepository.hasMoreForCategory(category.name),
        );
      case WallpaperSource.downloaded:
      case WallpaperSource.unknown:
        return Result.error(const ValidationFailure('Unsupported category source'));
    }
  }

  Result<CategoryFeedPage> _toPage<W>(
    Result<List<W>> result, {
    required String label,
    required FeedItemEntity Function(W wall) toItem,
    required bool hasMore,
  }) {
    final walls = result.data;
    if (walls == null) {
      return Result.error(result.failure ?? UnknownFailure('Failed to fetch $label feed'));
    }
    return Result.success(CategoryFeedPage(items: walls.map(toItem).toList(growable: false), hasMore: hasMore));
  }

  Future<void> _writeCache(CategoryEntity category, CategoryFeedPage page) {
    return _feedCacheLocal.write(
      source: 'category',
      scope: _scopeFor(category),
      ttlHours: _feedTtlHours,
      payload: <String, Object?>{
        'items': page.items.map(encodeFeedItem).toList(growable: false),
        'hasMore': page.hasMore,
      },
    );
  }

  Future<Result<CategoryFeedPage>> _cachedOrFailure({
    required CategoryEntity category,
    required String mode,
    required Failure failure,
  }) async {
    final cached = await _readCached(category);
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

  Future<CategoryFeedPage?> _readCached(CategoryEntity category) async {
    final snapshot = await _feedCacheLocal.read(source: 'category', scope: _scopeFor(category));
    final payload = toJsonMap(snapshot?.payload);
    final items = ((payload['items'] as List?) ?? const <Object?>[])
        .map((entry) => decodeFeedItem(toJsonMap(entry)))
        .nonNulls
        .toList(growable: false);

    if (items.isEmpty) {
      return null;
    }

    return CategoryFeedPage(items: items, hasMore: payload['hasMore'] == true);
  }

  String _scopeFor(CategoryEntity category) {
    final String base = '${category.source.wireValue}.${category.searchType.name}.${feedCacheSlug(category.name)}';
    return switch (category.source) {
      WallpaperSource.wallhaven =>
        '$base.${_settingsLocal.get<int>('WHcategories', defaultValue: 100)}'
            '.${_settingsLocal.get<int>('WHpurity', defaultValue: 100)}.portrait',
      WallpaperSource.pexels => '$base.portrait',
      _ => base,
    };
  }
}
