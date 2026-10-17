import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/notifications/notification_tombstones.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_store.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:Prism/features/ios_shortcuts/data/shortcuts_favourites_store.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_upload/data/upload_draft_store.dart';
import 'package:Prism/logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef LocalClearStep = ({String name, Future<void> Function(String userId) run});

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
    (name: 'favourites', run: (String userId) => getIt<FavoritesLocalDataSource>().clearUser(userId)),
    (name: 'iOS favourites mirror', run: ShortcutsFavouritesStore.clearForUser),
    (name: 'native favourites paths', run: NativeAssetPathsStore.clearForUser),
    (name: 'Android favourites mirror', run: _clearAndroidFavouritesForUser),
    (name: 'guest favourites', run: (_) => getIt<GuestFavouritesStore>().clear()),
    (name: 'downloaded wallpaper index', run: (String userId) => getIt<DownloadedWallIndex>().clearOwner(userId)),
    (name: 'wallpaper history', run: (_) => getIt<WallpaperHistoryStore>().clear()),
    (name: 'feed cache', run: (_) => getIt<FeedCacheLocalDataSource>().clearAllFeedCaches()),
    (
      name: 'user blocks',
      run: (String userId) async {
        if (getIt.isRegistered<UserBlockRepository>()) {
          await getIt<UserBlockRepository>().clearForUser(userId);
        } else {
          await _clearOwnerRecords('user_blocks', userId);
        }
      },
    ),
    (
      name: 'public profile snapshots',
      run: (String userId) async {
        if (getIt.isRegistered<PublicProfileRepository>()) {
          await getIt<PublicProfileRepository>().clearForUser(userId);
        } else {
          await _clearOwnerRecords('public_profiles', userId);
        }
      },
    ),
    (name: 'notification inbox', run: (String userId) => getIt<NotificationsLocalDataSource>().clearForUser(userId)),
    (name: 'notification tombstones', run: (String userId) => getIt<NotificationTombstones>().clearForUser(userId)),
    (name: 'upload drafts', run: (String userId) => UploadDraftStore().clearForUser(userId)),
    (name: 'AI history and prompts', run: (String userId) => getIt<AiGenerationRepositoryImpl>().clearForUser(userId)),
  ];

  static Future<void> _clearOwnerRecords(String storeName, String userId) async {
    final DurableJsonStore store = DurableJsonStore(storeName);
    final records = await store.readAll();
    for (final key in records.keys.where((key) => key.startsWith('${userId.trim()}::'))) {
      await store.delete(key);
    }
  }

  static Future<void> _clearAndroidFavouritesForUser(String userId) async {
    final String owner = userId.trim();
    final String activeOwner = app_state.prismUser.loggedIn ? app_state.prismUser.id.trim() : '';
    if (owner.isEmpty || (activeOwner.isNotEmpty && activeOwner != owner)) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String savedOwner = prefs.getString(NativeAssetPathsStore.privateOwnerKey)?.trim() ?? '';
    if (savedOwner.isNotEmpty && savedOwner != owner) return;
    await QuickTileConfigService.pushFavWallUrls(const <String>[]);
  }
}
