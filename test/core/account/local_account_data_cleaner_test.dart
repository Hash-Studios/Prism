import 'package:Prism/core/account/local_account_data_cleaner.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_store.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockGuestFavouritesStore extends Mock implements GuestFavouritesStore {}

class _MockFeedCache extends Mock implements FeedCacheLocalDataSource {}

void main() {
  tearDown(getIt.reset);

  test('every step runs and one failed step does not stop the rest', () async {
    final ran = <String>[];
    final cleaner = LocalAccountDataCleaner(
      steps: <LocalClearStep>[
        (name: 'a', run: (String id) async => ran.add('a:$id')),
        (name: 'b', run: (String id) async => throw StateError('disk full')),
        (name: 'c', run: (String id) async => ran.add('c:$id')),
      ],
    );

    await cleaner.clearForUser('user-1');

    expect(ran, <String>['a:user-1', 'c:user-1']);
  });

  test('the default steps empty the favourite ids, guest favourites, download index, history and feed cache', () async {
    await getIt.reset();
    final store = InMemoryLocalStore();
    final settings = SettingsLocalDataSource(store);
    final favourites = FavoritesLocalDataSource(store);
    await favourites.setWallFavourite('user-1', 'wall-1', true);
    await favourites.setWallFavourite('user-2', 'wall-9', true);
    await settings.set('downloaded_walls_v1', '{"name":{"id":"wall-1","source":"prism"}}');
    final history = WallpaperHistoryStore(settings);
    await history.record(
      AppliedWallpaper(
        id: 'wall-1',
        source: 'prism',
        thumbnailUrl: 't',
        fullUrl: 'f',
        target: 'home',
        appliedAt: DateTime.utc(2026),
      ),
    );
    final guest = _MockGuestFavouritesStore();
    when(guest.clear).thenAnswer((_) async {});
    final feed = _MockFeedCache();
    when(feed.clearAllFeedCaches).thenAnswer((_) async {});
    getIt
      ..registerSingleton<SettingsLocalDataSource>(settings)
      ..registerSingleton<FavoritesLocalDataSource>(favourites)
      ..registerSingleton<WallpaperHistoryStore>(history)
      ..registerSingleton<GuestFavouritesStore>(guest)
      ..registerSingleton<FeedCacheLocalDataSource>(feed);

    await LocalAccountDataCleaner().clearForUser('user-1');

    expect(favourites.isWallFavourite('user-1', 'wall-1'), isFalse);
    expect(favourites.isWallFavourite('user-2', 'wall-9'), isTrue);
    expect(store.data.containsKey('downloaded_walls_v1'), isFalse);
    expect(history.items(), isEmpty);
    verify(guest.clear).called(1);
    verify(feed.clearAllFeedCaches).called(1);
  });
}
