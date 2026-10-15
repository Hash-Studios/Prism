import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_store.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/logger/logger.dart';

typedef LocalClearStep = ({String name, Future<void> Function(String userId) run});

/// Removes what a deleted account left on this device: the favourite id set, the guest favourites, the downloaded
/// file index, the wallpaper history and the feed cache. One failed step never stops the others.
class LocalAccountDataCleaner {
  LocalAccountDataCleaner({List<LocalClearStep>? steps}) : _steps = steps ?? _defaultSteps();

  final List<LocalClearStep> _steps;

  Future<void> clearForUser(String userId) async {
    for (final LocalClearStep step in _steps) {
      try {
        await step.run(userId);
      } catch (error, stackTrace) {
        logger.w('Clearing ${step.name} after account deletion failed.', error: error, stackTrace: stackTrace);
      }
    }
  }

  static List<LocalClearStep> _defaultSteps() => <LocalClearStep>[
    (
      name: 'favourite ids',
      run: (String userId) => getIt<FavoritesLocalDataSource>().replaceWallFavourites(userId, const <String>[]),
    ),
    (name: 'guest favourites', run: (_) => getIt<GuestFavouritesStore>().clear()),
    (name: 'downloaded wallpaper index', run: (_) => getIt<DownloadedWallIndex>().clear()),
    (name: 'wallpaper history', run: (_) => getIt<WallpaperHistoryStore>().clear()),
    (name: 'feed cache', run: (_) => getIt<FeedCacheLocalDataSource>().clearAllFeedCaches()),
  ];
}
