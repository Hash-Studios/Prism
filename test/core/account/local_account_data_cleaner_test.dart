import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/account/local_account_data_cleaner.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/ios_widget_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_widget_api.g.dart';
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
    await favourites.updateWallSnapshot('user-1', (_) => <FavouriteWallEntity>[prismFav('wall-1')]);
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
    final privateEconomy = DurableJsonStore('private_economy');
    final drawTickets = DurableJsonStore('draw_read_snapshots');
    final friendRanks = DurableJsonStore('leaderboard_read_snapshots');
    for (final String owner in <String>['user-1', 'user-2']) {
      await privateEconomy.write(owner, <String, Object?>{'ownerId': owner, 'rev': 1, 'data': <String, Object?>{}});
      await drawTickets.write('tickets:$owner', <String, Object?>{'count': 1});
      await friendRanks.write('friends:$owner', <String, Object?>{'entries': <Object?>[]});
    }
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
    expect(await privateEconomy.read('user-1'), isNull);
    expect(await privateEconomy.read('user-2'), isNotNull);
    expect(await drawTickets.read('tickets:user-1'), isNull);
    expect(await drawTickets.read('tickets:user-2'), isNotNull);
    expect(await friendRanks.read('friends:user-1'), isNull);
    expect(await friendRanks.read('friends:user-2'), isNotNull);
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

  test('account deletion clears only its auto-rotate pass record', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);

    await settings.set('autoRotate.passRecord', jsonEncode(<String, Object?>{'ownerId': 'user-2', 'untilMs': 1}));
    await LocalAccountDataCleaner().clearForUser('user-1');
    expect(settings.get<String?>('autoRotate.passRecord'), contains('user-2'));

    await settings.set('autoRotate.passRecord', jsonEncode(<String, Object?>{'ownerId': 'user-1', 'untilMs': 1}));
    await LocalAccountDataCleaner().clearForUser('user-1');
    expect(settings.get<String?>('autoRotate.passRecord'), isNull);
  });

  group('iOS widget streak', () {
    late _FakeWidgetApi widgets;

    setUp(() {
      widgets = _FakeWidgetApi();
      IosWidgetChannel.api = widgets;
      IosWidgetChannel.isSupportedPlatform = () => true;
    });

    tearDown(() {
      IosWidgetChannel.api = PrismWidgetHostApi();
      IosWidgetChannel.isSupportedPlatform = () => false;
    });

    test('clears the snapshot once the deleted account is signed out', () async {
      app_state.prismUser = profileUser(id: '', loggedIn: false);

      await LocalAccountDataCleaner.clearIosWidgetStreakForUser('deleted');

      expect(widgets.snapshots, <StreakWidgetSnapshot?>[null]);
    });

    test('keeps the snapshot of another account that signed in first', () async {
      app_state.prismUser = profileUser(id: 'other');

      await LocalAccountDataCleaner.clearIosWidgetStreakForUser('deleted');

      expect(widgets.snapshots, isEmpty);
    });
  });
}

class _FakeWidgetApi implements PrismWidgetHostApi {
  final List<StreakWidgetSnapshot?> snapshots = <StreakWidgetSnapshot?>[];

  @override
  Future<void> setStreakSnapshot(StreakWidgetSnapshot? snapshot) async => snapshots.add(snapshot);

  @override
  Future<void> reloadWallOfTheDay() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
