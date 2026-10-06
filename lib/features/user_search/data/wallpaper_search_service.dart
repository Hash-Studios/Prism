import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/data/prism_wall_search.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

/// [prismResults] are Prism catalogue walls that match the query by tag or category. They are empty when nothing
/// matches or the Prism query fails.
typedef WallpaperSearchPage = ({
  SearchProviderValue provider,
  List<FeedItemEntity> results,
  List<FeedItemEntity> prismResults,
});

/// Thrown by [WallpaperSearchService.search] when Wallhaven and Pexels both fail.
class WallpaperSearchException implements Exception {
  const WallpaperSearchException(this.message);

  final String message;

  @override
  String toString() => 'WallpaperSearchException: $message';
}

/// Free-text wallpaper search over Wallhaven, with Pexels as the fallback, plus matching Prism walls.
@lazySingleton
class WallpaperSearchService {
  WallpaperSearchService(this._wallhavenRepository, this._pexelsRepository, this._settingsLocal, this._prismSearch);

  final WallhavenWallpaperRepository _wallhavenRepository;
  final PexelsWallpaperRepository _pexelsRepository;
  final SettingsLocalDataSource _settingsLocal;
  final PrismWallSearch _prismSearch;

  /// First page of [query]. When Wallhaven fails the search moves to Pexels so the user still gets results.
  /// Throws [WallpaperSearchException] when both providers fail.
  Future<WallpaperSearchPage> search(String query, {SearchFilters filters = const SearchFilters()}) async {
    final Future<List<FeedItemEntity>> prism = _prismResults(query, filters);
    try {
      return (
        provider: SearchProviderValue.wallhaven,
        results: await fetchPage(SearchProviderValue.wallhaven, query, refresh: true, filters: filters),
        prismResults: await prism,
      );
    } catch (error, stackTrace) {
      logger.w('Wallhaven search failed; falling back to Pexels.', error: error, stackTrace: stackTrace);
    }
    try {
      return (
        provider: SearchProviderValue.pexels,
        results: await fetchPage(SearchProviderValue.pexels, query, refresh: true, filters: filters),
        prismResults: await prism,
      );
    } catch (error, stackTrace) {
      logger.e('Pexels search failed.', error: error, stackTrace: stackTrace);
      throw WallpaperSearchException('Wallhaven and Pexels both failed: $error');
    }
  }

  /// One page from [provider]. The repository keeps the page cursor per [query]; [refresh] restarts it.
  /// Throws when the provider fails.
  Future<List<FeedItemEntity>> fetchPage(
    SearchProviderValue provider,
    String query, {
    required bool refresh,
    SearchFilters filters = const SearchFilters(),
  }) async {
    if (provider == SearchProviderValue.pexels) {
      final result = await _pexelsRepository.fetchFeed(
        categoryName: query,
        refresh: refresh,
        paginationKey: _paginationKey(query),
        portraitOnly: filters.portraitOnly,
      );
      return result.fold(
        onSuccess: (walls) => walls
            .where((wall) => filters.acceptsResolution(wall.core.resolution))
            .map((wall) => PexelsFeedItem(id: wall.id, wallpaper: wall))
            .toList(growable: false),
        onFailure: (failure) => throw Exception(failure.message),
      );
    }
    final result = await _wallhavenRepository.fetchFeed(
      categoryName: query,
      refresh: refresh,
      paginationKey: _paginationKey(query),
      categories: _settingsLocal.get<int>('WHcategories', defaultValue: 100),
      purity: _settingsLocal.get<int>('WHpurity', defaultValue: 100),
      portraitOnly: filters.portraitOnly,
      minResolution: filters.minResolution,
      sorting: filters.wallhavenSorting,
    );
    return result.fold(
      onSuccess: (walls) =>
          walls.map((wall) => WallhavenFeedItem(id: wall.id, wallpaper: wall)).toList(growable: false),
      onFailure: (failure) => throw Exception(failure.message),
    );
  }

  String _paginationKey(String query) => 'search:$query';

  Future<List<FeedItemEntity>> _prismResults(String query, SearchFilters filters) async {
    final List<PrismWallpaper> walls = await _prismSearch.search(query);
    return walls
        .where((wall) => filters.acceptsResolution(wall.core.resolution))
        .map((wall) => PrismFeedItem(id: wall.id, wallpaper: wall))
        .toList(growable: false);
  }
}
