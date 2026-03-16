import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/collections/provider/collectionsWithoutProvider.dart';
import 'package:Prism/features/auto_rotate/data/data_sources/auto_rotate_local_data_source.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config_entity.dart';
import 'package:Prism/features/auto_rotate/domain/repositories/auto_rotate_repository.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/domain/usecases/category_feed_usecases.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:injectable/injectable.dart';

@LazySingleton(as: AutoRotateRepository)
class AutoRotateRepositoryImpl implements AutoRotateRepository {
  AutoRotateRepositoryImpl(this._localDataSource, this._fetchFavouriteWallsUseCase, this._fetchCategoryFeedUseCase);

  final AutoRotateLocalDataSource _localDataSource;
  final FetchFavouriteWallsUseCase _fetchFavouriteWallsUseCase;
  final FetchCategoryFeedUseCase _fetchCategoryFeedUseCase;

  @override
  Future<Result<AutoRotateConfigEntity>> loadConfig() async {
    try {
      return Result.success(_localDataSource.loadConfig());
    } catch (e) {
      return Result.error(CacheFailure('Failed to load auto rotate config: $e'));
    }
  }

  @override
  Future<Result<void>> saveConfig(AutoRotateConfigEntity config) async {
    try {
      await _localDataSource.saveConfig(config);
      return Result.success(null);
    } catch (e) {
      return Result.error(CacheFailure('Failed to save auto rotate config: $e'));
    }
  }

  @override
  Future<Result<void>> startRotation(AutoRotateConfigEntity config) async {
    try {
      final urls = await _fetchUrls(config);
      if (urls.isEmpty) {
        return Result.error(const ValidationFailure('No wallpapers found for the selected source.'));
      }

      final sources = urls
          .map((url) => aw.WallpaperRotationSource(sourceType: aw.WallpaperSourceType.url, source: url))
          .toList();

      final triggers = <aw.WallpaperRotationTrigger>{aw.WallpaperRotationTrigger.interval};
      if (config.chargingTrigger) {
        triggers.add(aw.WallpaperRotationTrigger.charging);
      }

      final request = aw.WallpaperRotationRequest(
        sources: sources,
        target: config.target,
        intervalMinutes: config.intervalMinutes,
        triggers: triggers,
        order: config.order == AutoRotateOrder.shuffle
            ? aw.WallpaperRotationOrder.shuffle
            : aw.WallpaperRotationOrder.sequential,
      );

      final result = await aw.AsyncWallpaper.startWallpaperRotation(request);
      if (!result.isSuccess) {
        return Result.error(const UnknownFailure('Failed to start wallpaper rotation.'));
      }

      await _localDataSource.saveConfig(config.copyWith(isEnabled: true));
      return Result.success(null);
    } catch (e) {
      return Result.error(UnknownFailure('Failed to start auto rotate: $e'));
    }
  }

  @override
  Future<Result<void>> stopRotation() async {
    try {
      await aw.AsyncWallpaper.stopWallpaperRotation();
      final config = _localDataSource.loadConfig();
      await _localDataSource.saveConfig(config.copyWith(isEnabled: false));
      return Result.success(null);
    } catch (e) {
      return Result.error(UnknownFailure('Failed to stop auto rotate: $e'));
    }
  }

  @override
  Future<Result<bool>> isRotationActive() async {
    try {
      final status = await aw.AsyncWallpaper.getWallpaperRotationStatus();
      return Result.success(status.isRunning);
    } catch (e) {
      return Result.error(UnknownFailure('Failed to get rotation status: $e'));
    }
  }

  Future<List<String>> _fetchUrls(AutoRotateConfigEntity config) async {
    switch (config.sourceType) {
      case AutoRotateSourceType.favourites:
        return _fetchFavouriteUrls();
      case AutoRotateSourceType.category:
        return _fetchCategoryUrls(config.categoryName ?? '');
      case AutoRotateSourceType.collection:
        return _fetchCollectionUrls(config.collectionName ?? '');
    }
  }

  Future<List<String>> _fetchFavouriteUrls() async {
    final userId = app_state.prismUser.id;
    final result = await _fetchFavouriteWallsUseCase(FetchFavouriteWallsParams(userId: userId));
    return result.fold(
      onSuccess: (walls) => walls.map((w) => w.fullUrl).where((url) => url.isNotEmpty).toList(),
      onFailure: (_) => <String>[],
    );
  }

  Future<List<String>> _fetchCategoryUrls(String categoryName) async {
    final definition = categoryDefinitions.firstWhere(
      (d) => d.name == categoryName,
      orElse: () => categoryDefinitions.first,
    );

    final category = CategoryEntity(
      name: definition.name,
      source: definition.source,
      searchType: definition.searchType,
      image: definition.imageUrl,
      image2: definition.secondaryImageUrl,
    );

    final result = await _fetchCategoryFeedUseCase(FetchCategoryFeedParams(category: category, refresh: true));
    return result.fold(
      onSuccess: (page) => page.items.map(_extractUrl).where((url) => url.isNotEmpty).toList(),
      onFailure: (_) => <String>[],
    );
  }

  Future<List<String>> _fetchCollectionUrls(String collectionName) async {
    await getCollectionWithName(collectionName);
    final walls = anyCollectionWalls ?? [];
    return walls.map((w) => w['wallpaper_url']?.toString() ?? '').where((url) => url.isNotEmpty).toList();
  }

  String _extractUrl(FeedItemEntity item) {
    return item.when(
      prism: (_, wallpaper) => wallpaper.fullUrl,
      wallhaven: (_, wallpaper) => wallpaper.fullUrl,
      pexels: (_, wallpaper) => wallpaper.fullUrl,
    );
  }
}
