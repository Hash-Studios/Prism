import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/categories/categories.dart' as category_data;
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/category_feed_page.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/domain/repositories/category_feed_repository.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:hive_io/hive_io.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: CategoryFeedRepository)
class CategoryFeedRepositoryImpl implements CategoryFeedRepository {
  CategoryFeedRepositoryImpl(
    @Named('prefsBox') this._prefsBox,
    this._prismRepository,
    this._wallhavenRepository,
    this._pexelsRepository,
  );

  final Box<dynamic> _prefsBox;
  final PrismWallpaperRepository _prismRepository;
  final WallhavenWallpaperRepository _wallhavenRepository;
  final PexelsWallpaperRepository _pexelsRepository;

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
            return Result.error(result.failure ?? const UnknownFailure('Failed to fetch Prism feed'));
          }
          final walls = result.data!;
          items = walls.map((wall) => PrismFeedItem(id: wall.id, wallpaper: wall)).toList(growable: false);
          hasMore = _prismRepository.hasMore;

        case WallpaperSource.wallhaven:
          final result = await _wallhavenRepository.fetchFeed(
            categoryName: category.name,
            refresh: refresh,
            categories: (_prefsBox.get('WHcategories', defaultValue: 100) as int?) ?? 100,
            purity: (_prefsBox.get('WHpurity', defaultValue: 100) as int?) ?? 100,
          );
          if (result.isFailure || result.data == null) {
            return Result.error(result.failure ?? const UnknownFailure('Failed to fetch Wallhaven feed'));
          }
          final walls = result.data!;
          items = walls.map((wall) => WallhavenFeedItem(id: wall.id, wallpaper: wall)).toList(growable: false);
          hasMore = _wallhavenRepository.hasMoreForCategory(category.name);

        case WallpaperSource.pexels:
          final result = await _pexelsRepository.fetchFeed(categoryName: category.name, refresh: refresh);
          if (result.isFailure || result.data == null) {
            return Result.error(result.failure ?? const UnknownFailure('Failed to fetch Pexels feed'));
          }
          final walls = result.data!;
          items = walls.map((wall) => PexelsFeedItem(id: wall.id, wallpaper: wall)).toList(growable: false);
          hasMore = _pexelsRepository.hasMoreForCategory(category.name);

        case WallpaperSource.wallOfTheDay:
        case WallpaperSource.downloaded:
        case WallpaperSource.unknown:
          return Result.error(const ValidationFailure('Unsupported category source'));
      }
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
}
