import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/account/local_account_data_cleaner.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/favourite_walls/data/guest_favourites_store.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import '../../support/in_memory_local_store.dart';
import '../../features/favourite_walls/support/fav_fixtures.dart';
import '../../support/profile_user_fixture.dart';

class _MockGuestFavouritesStore extends Mock implements GuestFavouritesStore {}

class _MockFeedCache extends Mock implements FeedCacheLocalDataSource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storeDirectory;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (_) async => storeDirectory.path,
  );
  setUp(() async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    storeDirectory = await Directory.systemTemp.createTemp('prism-account-cleaner-test-');
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });
  tearDown(() async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    await getIt.reset();
    if (await storeDirectory.exists()) await storeDirectory.delete(recursive: true);
  });

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
    await favourites.saveWallSnapshot('user-1', <FavouriteWallEntity>[prismFav('wall-1')]);
    await favourites.createFavouriteOperation(
      'user-1',
      'wall-1',
      desired: true,
      wall: <String, Object?>{'id': 'wall-1'},
    );
    final blockRecords = DurableJsonStore('user_blocks');
    await blockRecords.write('user-1::blocked-user', <String, Object?>{'owner': 'user-1'});
    await blockRecords.write('user-2::blocked-user', <String, Object?>{'owner': 'user-2'});
    final profileRecords = DurableJsonStore('public_profiles');
    await profileRecords.write('user-1::profile', <String, Object?>{'owner': 'user-1'});
    await profileRecords.write('user-2::profile', <String, Object?>{'owner': 'user-2'});
    final downloadedIndex = DownloadedWallIndex(settings);
    await downloadedIndex.remember(
      link: 'https://example.test/user-1.jpg',
      id: 'wall-1',
      source: WallpaperSource.prism,
      ownerId: 'user-1',
    );
    await downloadedIndex.remember(
      link: 'https://example.test/user-2.jpg',
      id: 'wall-2',
      source: WallpaperSource.prism,
      ownerId: 'user-2',
    );
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
    SharedPreferences.setMockInitialValues(<String, Object>{
      PersistenceKeys.shortcutsFavourites: '[{"id":"owner-b-wall","url":"https://example.com/b.jpg"}]',
      PersistenceKeys.quickTileFavWallUrls: '["https://example.com/b.jpg"]',
      NativeAssetPathsStore.privateOwnerKey: 'owner-b',
      NativeAssetPathsStore.preferenceKey: '{"https://example.com/b.jpg":"assets/b.asset"}',
      '${NativeAssetPathsStore.preferenceKey}.favourites': '{"https://example.com/b.jpg":"assets/b.asset"}',
      '${NativeAssetPathsStore.preferenceKey}.shortcuts': '{"https://example.com/b.jpg":"assets/b.asset"}',
    });
    getIt
      ..registerSingleton<SettingsLocalDataSource>(settings)
      ..registerSingleton<DownloadedWallIndex>(downloadedIndex)
      ..registerSingleton<FavoritesLocalDataSource>(favourites)
      ..registerSingleton<WallpaperHistoryStore>(history)
      ..registerSingleton<GuestFavouritesStore>(guest)
      ..registerSingleton<FeedCacheLocalDataSource>(feed);

    app_state.prismUser = profileUser(id: 'owner-b', loggedIn: true);
    await LocalAccountDataCleaner().clearForUser('user-1');
    app_state.prismUser = profileUser(id: '', loggedIn: false);

    expect(favourites.isWallFavourite('user-1', 'wall-1'), isFalse);
    expect(favourites.isWallFavourite('user-2', 'wall-9'), isTrue);
    expect(await favourites.readWallSnapshot('user-1'), isEmpty);
    expect(await favourites.readFavouriteOperation('user-1', 'wall-1'), isNull);
    expect(await blockRecords.read('user-1::blocked-user'), isNull);
    expect(await blockRecords.read('user-2::blocked-user'), isNotNull);
    expect(await profileRecords.read('user-1::profile'), isNull);
    expect(await profileRecords.read('user-2::profile'), isNotNull);
    final acquisitions = jsonDecode(settings.get<String>('downloaded_walls_v1', defaultValue: '{}')) as Map;
    expect(acquisitions.values.map((value) => value['owner']), <String>['user-2']);
    expect(history.items(), isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(PersistenceKeys.shortcutsFavourites), contains('b.jpg'));
    expect(preferences.getString(PersistenceKeys.quickTileFavWallUrls), contains('b.jpg'));
    expect(preferences.getString(NativeAssetPathsStore.preferenceKey), contains('b.jpg'));
    expect(preferences.getString('${NativeAssetPathsStore.preferenceKey}.favourites'), contains('b.jpg'));
    expect(preferences.getString('${NativeAssetPathsStore.preferenceKey}.shortcuts'), contains('b.jpg'));
    verify(guest.clear).called(1);
    verify(feed.clearAllFeedCaches).called(1);
  });
}
