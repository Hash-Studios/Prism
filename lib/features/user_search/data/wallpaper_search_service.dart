import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

typedef WallpaperSearchPage = ({SearchProviderValue provider, List<FeedItemEntity> results});

/// Free-text wallpaper search over Wallhaven, with Pexels as the fallback.
@lazySingleton
class WallpaperSearchService {
  WallpaperSearchService(this._wallhavenRepository, this._pexelsRepository, this._settingsLocal);

  final WallhavenWallpaperRepository _wallhavenRepository;
  final PexelsWallpaperRepository _pexelsRepository;
  final SettingsLocalDataSource _settingsLocal;

  /// First page of [query]. When Wallhaven fails the search moves to Pexels so the user still gets results.
  Future<WallpaperSearchPage> search(String query) async {
    try {
      return (
        provider: SearchProviderValue.wallhaven,
        results: await fetchPage(SearchProviderValue.wallhaven, query, refresh: true),
      );
    } catch (error, stackTrace) {
      logger.w('Wallhaven search failed; falling back to Pexels.', error: error, stackTrace: stackTrace);
    }
    try {
      return (
        provider: SearchProviderValue.pexels,
        results: await fetchPage(SearchProviderValue.pexels, query, refresh: true),
      );
    } catch (error, stackTrace) {
      logger.e('Pexels search failed.', error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// One page from [provider]. The repository keeps the page cursor per [query]; [refresh] restarts it.
  /// Throws when the provider fails.
  Future<List<FeedItemEntity>> fetchPage(SearchProviderValue provider, String query, {required bool refresh}) async {
    if (provider == SearchProviderValue.pexels) {
      final result = await _pexelsRepository.fetchFeed(categoryName: query, refresh: refresh);
      return result.fold(
        onSuccess: (walls) => walls.map((wall) => PexelsFeedItem(id: wall.id, wallpaper: wall)).toList(growable: false),
        onFailure: (failure) => throw Exception(failure.message),
      );
    }
    final result = await _wallhavenRepository.fetchFeed(
      categoryName: query,
      refresh: refresh,
      categories: _settingsLocal.get<int>('WHcategories', defaultValue: 100),
      purity: _settingsLocal.get<int>('WHpurity', defaultValue: 100),
    );
    return result.fold(
      onSuccess: (walls) =>
          walls.map((wall) => WallhavenFeedItem(id: wall.id, wallpaper: wall)).toList(growable: false),
      onFailure: (failure) => throw Exception(failure.message),
    );
  }
}
