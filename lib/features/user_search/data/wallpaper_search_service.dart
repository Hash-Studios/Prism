import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/debug/performance_probe.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
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
  bool isLocal,
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
  WallpaperSearchService(
    this._wallhavenRepository,
    this._pexelsRepository,
    this._settingsLocal,
    this._prismSearch, [
    @ignoreParam OfflineWallpaperCatalog? offlineCatalog,
  ]) : _offlineCatalog = offlineCatalog ?? OfflineWallpaperCatalog.instance;

  final WallhavenWallpaperRepository _wallhavenRepository;
  final PexelsWallpaperRepository _pexelsRepository;
  final SettingsLocalDataSource _settingsLocal;
  final PrismWallSearch _prismSearch;
  final OfflineWallpaperCatalog _offlineCatalog;
  static const Duration _cachedSearchDecisionBudget = Duration(seconds: 3);
  static const int _prismLimit = 12;

  /// The Depth Effect list has no next page, so a browse asks for a full screen at once.
  static const int _depthBrowseLimit = 48;

  /// First page of [query]. An empty [query] is allowed with a colour filter. Pexels needs a query, so a colour-only
  /// search skips it. When Wallhaven fails the search moves to Pexels so the user still gets results.
  /// When both providers fail but Prism has matches, the page has provider [SearchProviderValue.prism], no
  /// [WallpaperSearchPage.results] and no external pagination. Throws [WallpaperSearchException] when Prism is empty too.
  /// With [SearchFilters.depthOnly] only Prism walls can match, so the page holds them as [WallpaperSearchPage.results]
  /// and never throws.
  Future<WallpaperSearchPage> search(String query, {SearchFilters filters = const SearchFilters()}) {
    return PerformanceProbe.measure('search', 'wallpaper.search', () => _search(query, filters: filters));
  }

  Future<WallpaperSearchPage> _search(String query, {SearchFilters filters = const SearchFilters()}) async {
    if (filters.depthOnly) return _depthSearch(query, filters);
    final Future<List<FeedItemEntity>> wallhavenFetch = fetchPage(
      SearchProviderValue.wallhaven,
      query,
      refresh: true,
      filters: filters,
    )..ignore();
    final Future<List<FeedItemEntity>> prismSearch = _prismResults(query, filters);
    List<FeedItemEntity> cachedResults = const <FeedItemEntity>[];
    try {
      cachedResults = await _localResults(query, filters);
    } catch (error) {
      logger.w('Local wallpaper catalog search failed: $error');
    }
    final Future<List<FeedItemEntity>> prism = cachedResults.isEmpty
        ? prismSearch
        : prismSearch.timeout(_cachedSearchDecisionBudget, onTimeout: () => const <FeedItemEntity>[]);
    bool usedLocalFallback = false;
    try {
      return (
        provider: SearchProviderValue.wallhaven,
        results: cachedResults.isEmpty
            ? await wallhavenFetch
            : await wallhavenFetch.timeout(
                _cachedSearchDecisionBudget,
                onTimeout: () {
                  usedLocalFallback = true;
                  return cachedResults;
                },
              ),
        prismResults: await prism,
        isLocal: usedLocalFallback,
      );
    } catch (error, stackTrace) {
      logger.w('Wallhaven search failed; falling back to Pexels.', error: error, stackTrace: stackTrace);
    }
    Object failure = 'Wallhaven failed and there is no query for Pexels.';
    if (query.trim().isNotEmpty) {
      try {
        return (
          provider: SearchProviderValue.pexels,
          results: cachedResults.isEmpty
              ? await fetchPage(SearchProviderValue.pexels, query, refresh: true, filters: filters)
              : await fetchPage(SearchProviderValue.pexels, query, refresh: true, filters: filters).timeout(
                  _cachedSearchDecisionBudget,
                  onTimeout: () {
                    usedLocalFallback = true;
                    return cachedResults;
                  },
                ),
          prismResults: await prism,
          isLocal: usedLocalFallback,
        );
      } catch (error, stackTrace) {
        logger.e('Pexels search failed.', error: error, stackTrace: stackTrace);
        failure = error;
      }
    }
    final List<FeedItemEntity> prismResults = await prism;
    if (prismResults.isNotEmpty) {
      return (
        provider: SearchProviderValue.prism,
        results: const <FeedItemEntity>[],
        prismResults: prismResults,
        isLocal: false,
      );
    }
    try {
      if (cachedResults.isNotEmpty) {
        return (
          provider: SearchProviderValue.wallhaven,
          results: cachedResults,
          prismResults: const <FeedItemEntity>[],
          isLocal: true,
        );
      }
    } catch (error) {
      logger.w('Local wallpaper catalog search failed: $error');
    }
    throw WallpaperSearchException('Wallhaven and Pexels both failed: $failure');
  }

  Future<WallpaperSearchPage> _depthSearch(String query, SearchFilters filters) async {
    List<FeedItemEntity> results = await _prismResults(query, filters);
    bool isLocal = false;
    if (results.isEmpty) {
      try {
        results = await _localResults(query, filters);
        isLocal = results.isNotEmpty;
      } catch (error) {
        logger.w('Local wallpaper catalog search failed: $error');
      }
    }
    return (
      provider: SearchProviderValue.prism,
      results: results,
      prismResults: const <FeedItemEntity>[],
      isLocal: isLocal,
    );
  }

  Future<List<FeedItemEntity>> _localResults(String query, SearchFilters filters) async {
    final List<FeedItemEntity> local = (await _offlineCatalog.search(
      query,
      limit: 100,
    )).where((item) => _matchesLocalFilters(item, filters)).toList(growable: false);
    if (local.isNotEmpty || filters.color == null) return local;
    return (await _offlineCatalog.search(
      filters.color!.id,
      limit: 100,
    )).where((item) => _matchesLocalFilters(item, filters)).toList(growable: false);
  }

  bool _matchesLocalFilters(FeedItemEntity item, SearchFilters filters) {
    if (!filters.acceptsResolution(item.wallpaperCore.resolution)) return false;
    if (filters.depthOnly) {
      final bool supportsDepth = item.when(
        prism: (_, wall) => wall.depthTier?.supportsDepth ?? false,
        wallhaven: (_, _) => false,
        pexels: (_, _) => false,
      );
      if (!supportsDepth) return false;
    }
    final color = filters.color;
    if (color == null) return true;
    final List<String> colors = item.when(
      prism: (_, wall) => wall.colors ?? const <String>[],
      wallhaven: (_, wall) => wall.colors ?? const <String>[],
      pexels: (_, _) => const <String>[],
    );
    return colors.any((value) => value.toLowerCase() == color.id || value.toLowerCase() == color.hex.toLowerCase());
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
        paginationKey: _paginationKey(query, filters),
        portraitOnly: filters.portraitOnly,
        color: filters.color?.pexelsName,
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
      paginationKey: _paginationKey(query, filters),
      categories: _settingsLocal.get<int>('WHcategories', defaultValue: 100),
      purity: _settingsLocal.get<int>('WHpurity', defaultValue: 100),
      portraitOnly: filters.portraitOnly,
      minResolution: filters.minResolution,
      sorting: filters.wallhavenSorting,
      colors: filters.color?.hex,
    );
    return result.fold(
      onSuccess: (walls) =>
          walls.map((wall) => WallhavenFeedItem(id: wall.id, wallpaper: wall)).toList(growable: false),
      onFailure: (failure) => throw Exception(failure.message),
    );
  }

  String _paginationKey(String query, SearchFilters filters) =>
      filters.color == null ? 'search:$query' : 'search:$query:color:${filters.color!.id}';

  Future<List<FeedItemEntity>> _prismResults(String query, SearchFilters filters) async {
    final List<PrismWallpaper> walls = await _prismSearch.search(
      query,
      limit: filters.depthOnly && query.trim().isEmpty ? _depthBrowseLimit : _prismLimit,
      colorId: filters.color?.id,
      depthOnly: filters.depthOnly,
    );
    return walls
        .where((wall) => filters.acceptsResolution(wall.core.resolution))
        .map((wall) => PrismFeedItem(id: wall.id, wallpaper: wall))
        .toList(growable: false);
  }
}
