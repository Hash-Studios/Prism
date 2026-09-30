// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/auth/badge_model.dart';
import 'package:Prism/auth/transaction_model.dart';
import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_walls_repository.dart';
import 'package:Prism/features/personalized_feed/data/feed_impression_store.dart';
import 'package:Prism/features/personalized_feed/data/personalized_feed_repository_impl.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_remote_config_platform_interface/firebase_remote_config_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';

class _FakeFirebaseRemoteConfigPlatform extends FirebaseRemoteConfigPlatform {
  @override
  FirebaseRemoteConfigPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseRemoteConfigPlatform setInitialValues({required Map<Object?, Object?> remoteConfigValues}) => this;

  @override
  String getString(String key) => '';
}

class _EmptyFirestore extends Fake implements FirestoreClient {
  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async =>
      <T>[];

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic>, String) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async => null;
}

class _OneWallFirestore extends Fake implements FirestoreClient {
  static const Map<String, dynamic> _wall = <String, dynamic>{
    'wallpaper_url': 'https://example.com/wall.jpg',
    'wallpaper_thumb': 'https://example.com/thumb.jpg',
    'wallpaper_provider': 'prism',
    'review': true,
    'email': 'creator@example.com',
    'createdAt': '2026-09-01T00:00:00Z',
  };

  bool fail = false;
  bool failUserDoc = false;
  bool onlyHiddenFresh = false;

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    if (onlyHiddenFresh) {
      if (spec.sourceTag != 'personalized.fresh') {
        throw StateError('offline');
      }
      return <T>[map(_wall, 'wall-doc')];
    }
    if (fail) {
      throw StateError('offline');
    }
    return <T>[
      map(_wall, 'wall-doc'),
      map(<String, dynamic>{..._wall, 'wallpaper_url': 'https://example.com/visible.jpg'}, 'visible-doc'),
    ];
  }

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async => failUserDoc ? throw StateError('offline') : null;
}

class _OfflineFirestore extends Fake implements FirestoreClient {
  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async =>
      throw StateError('offline');

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async => null;
}

class _EmptyFeedCache extends FeedCacheLocalDataSource {
  @override
  Future<FeedSnapshot?> read({required String source, required String scope}) async => null;

  @override
  Future<void> write({
    required String source,
    required String scope,
    required Object? payload,
    required int ttlHours,
  }) async {}
}

class _MemoryFeedCache extends FeedCacheLocalDataSource {
  FeedSnapshot? snapshot;

  @override
  Future<FeedSnapshot?> read({required String source, required String scope}) async => snapshot;

  @override
  Future<void> write({
    required String source,
    required String scope,
    required Object? payload,
    required int ttlHours,
  }) async {
    snapshot = FeedSnapshot(payload: payload, cachedAtUtc: DateTime.now().toUtc(), ttlHours: ttlHours);
  }
}

class _EmptyWallhaven extends Fake implements WallhavenWallpaperRepository {
  @override
  Future<Result<List<WallhavenWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int categories = 100,
    int purity = 100,
    int startPage = 1,
    String? paginationKey,
  }) async => Result.success(<WallhavenWallpaper>[]);
}

class _EmptyPexels extends Fake implements PexelsWallpaperRepository {
  @override
  Future<Result<List<PexelsWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int startPage = 1,
    String? paginationKey,
  }) async => Result.success(<PexelsWallpaper>[]);
}

class _ToggleWallhaven extends Fake implements WallhavenWallpaperRepository {
  bool fail = false;

  @override
  Future<Result<List<WallhavenWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int categories = 100,
    int purity = 100,
    int startPage = 1,
    String? paginationKey,
  }) async => fail ? Result.error(const UnknownFailure('offline')) : Result.success(<WallhavenWallpaper>[]);
}

class _TogglePexels extends Fake implements PexelsWallpaperRepository {
  bool fail = false;

  @override
  Future<Result<List<PexelsWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int startPage = 1,
    String? paginationKey,
  }) async => fail ? Result.error(const UnknownFailure('offline')) : Result.success(<PexelsWallpaper>[]);
}

class _OfflineWallhaven extends Fake implements WallhavenWallpaperRepository {
  @override
  Future<Result<List<WallhavenWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int categories = 100,
    int purity = 100,
    int startPage = 1,
    String? paginationKey,
  }) async => Result.error(const UnknownFailure('offline'));
}

class _OfflinePexels extends Fake implements PexelsWallpaperRepository {
  @override
  Future<Result<List<PexelsWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int startPage = 1,
    String? paginationKey,
  }) async => Result.error(const UnknownFailure('offline'));
}

class _EmptyBlocks extends Fake implements UserBlockRepository {
  bool failNext = false;

  @override
  Future<Set<String>> getBlockedCreatorEmails({bool waitForInitialLoad = false}) async {
    if (failNext) {
      failNext = false;
      throw StateError('offline');
    }
    return <String>{};
  }
}

class _FailingFavourites extends Fake implements FavouriteWallsRepository {
  @override
  Future<Result<List<FavouriteWallEntity>>> fetchFavourites({required String userId}) async =>
      throw StateError('offline');
}

class _CountingFavourites extends Fake implements FavouriteWallsRepository {
  int calls = 0;

  @override
  Future<Result<List<FavouriteWallEntity>>> fetchFavourites({required String userId}) async {
    calls++;
    return Result.success(<FavouriteWallEntity>[]);
  }
}

class _PendingFavourites extends Fake implements FavouriteWallsRepository {
  final Completer<Result<List<FavouriteWallEntity>>> completer = Completer<Result<List<FavouriteWallEntity>>>();
  int calls = 0;

  @override
  Future<Result<List<FavouriteWallEntity>>> fetchFavourites({required String userId}) {
    calls++;
    return completer.future;
  }
}

PrismUsersV2 _signedInUser() {
  final String now = DateTime.now().toUtc().toIso8601String();
  return PrismUsersV2(
    username: '',
    email: '',
    id: 'feed-test-user',
    createdAt: now,
    premium: false,
    lastLoginAt: now,
    links: const <String, String>{},
    followers: const <String>[],
    following: const <String>[],
    profilePhoto: '',
    bio: '',
    loggedIn: true,
    badges: <Badge>[],
    subPrisms: const <String>[],
    coins: 0,
    transactions: <PrismTransaction>[],
    name: '',
    coverPhoto: '',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(TasteSignal.clearRememberedFeedTerms);
  tearDown(TasteSignal.clearRememberedFeedTerms);

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseRemoteConfigPlatform.instance = _FakeFirebaseRemoteConfigPlatform();
  });

  test('less-like-this records remembered terms and hides a tagless external wall', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    final TasteSignalStore signals = TasteSignalStore(settings);
    final PersonalizedFeedRepository repository = _repository(
      firestore: _EmptyFirestore(),
      settings: settings,
      favourites: _CountingFavourites(),
      tasteSignals: signals,
    );
    const WallhavenWallpaper wall = WallhavenWallpaper(
      core: WallpaperCore(
        id: 'wall',
        source: WallpaperSource.wallhaven,
        fullUrl: ' HTTPS://EXAMPLE.COM/WALL.JPG ',
        thumbnailUrl: 't',
        category: 'general',
      ),
    );
    rememberFeedTerms('https://example.com/wall.jpg', <String>['Space']);
    rememberFeedTerms('https://example.com/wall.jpg', <String>['Sky']);

    await repository.lessLikeThis(const WallhavenFeedItem(id: 'wall', wallpaper: wall));

    expect(signals.read().single.action, TasteAction.lessLikeThis);
    expect(signals.read().single.terms, <String>['space', 'sky']);
    expect(FeedImpressionStore(settings).recentShows(DateTime.now().toUtc()), <String, int>{
      'https://example.com/wall.jpg': 99,
    });
  });

  test('favourite seeding failure does not fail the feed', () async {
    app_state.prismUser = _signedInUser();
    final result = await _repository(
      favourites: _FailingFavourites(),
      firestore: _OneWallFirestore(),
      settings: SettingsLocalDataSource(InMemoryLocalStore()),
    ).fetch(_firstPage);

    expect(_itemIds(result.data?.items ?? const <FeedItemEntity>[]), <String>['visible-doc', 'wall-doc']);
  });

  test('guest feed skips favourite seeding', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    final _CountingFavourites favourites = _CountingFavourites();
    app_state.prismUser = app_constants.createGuestPrismUser();
    final PersonalizedFeedRepository repository = _repository(
      favourites: favourites,
      firestore: _OneWallFirestore(),
      settings: settings,
    );

    final result = await repository.fetch(_firstPage);

    expect(_itemIds(result.data?.items ?? const <FeedItemEntity>[]), <String>['visible-doc', 'wall-doc']);
    expect(favourites.calls, 0);
  });

  test('slow favourite seeding cannot hold the feed open', () async {
    final InMemoryLocalStore store = InMemoryLocalStore();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(store);
    final TasteSignalStore signals = TasteSignalStore(settings);
    final _PendingFavourites favourites = _PendingFavourites();
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      favourites: favourites,
      firestore: _OneWallFirestore(),
      settings: settings,
      tasteSignals: signals,
    );
    final result = await repository.fetch(_firstPage).timeout(const Duration(seconds: 2));

    expect(_itemIds(result.data?.items ?? const <FeedItemEntity>[]), <String>['visible-doc', 'wall-doc']);
    expect(favourites.calls, 1);
    favourites.completer.complete(Result.success(<FavouriteWallEntity>[_favourite('late-favourite')]));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(signals.isSeeded, isTrue);
    expect(signals.read(), hasLength(1));
    await repository.fetch(_firstPage);
    expect(favourites.calls, 1);
  });

  test('late favourite seeding does not restore taste after clear', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    final TasteSignalStore signals = TasteSignalStore(settings);
    final _PendingFavourites favourites = _PendingFavourites();
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      favourites: favourites,
      firestore: _OneWallFirestore(),
      settings: settings,
      tasteSignals: signals,
    );
    final result = await repository.fetch(_firstPage).timeout(const Duration(seconds: 2));
    expect(_itemIds(result.data?.items ?? const <FeedItemEntity>[]), <String>['visible-doc', 'wall-doc']);

    await signals.clear();
    favourites.completer.complete(Result.success(<FavouriteWallEntity>[_favourite('late-favourite')]));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(signals.isSeeded, isTrue);
    expect(signals.read(), isEmpty);
  });

  test('existing items stay excluded after the seen-key window is trimmed', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      favourites: _CountingFavourites(),
      firestore: _OneWallFirestore(),
      settings: settings,
    );
    final first = await repository.fetch(_firstPage);
    expect(first.isSuccess, isTrue);
    expect(first.data!.items, hasLength(2));

    final next = await repository.fetch(
      FetchPersonalizedFeedRequest(
        page: 2,
        refresh: false,
        seenKeys: const <String>[],
        existingItems: first.data!.items,
      ),
    );

    expect(next.isSuccess, isTrue);
    expect(next.data!.items, isEmpty);
    expect(next.data!.hasMore, isFalse);
  });

  test('all source failures return a failure instead of a successful empty feed', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set('onboarding_v2_interests', 'Photography');
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      firestore: _OfflineFirestore(),
      wallhaven: _OfflineWallhaven(),
      pexels: _OfflinePexels(),
      cache: _EmptyFeedCache(),
      favourites: _CountingFavourites(),
      settings: settings,
    );

    final result = await repository.fetch(_firstPage);

    expect(result.isFailure, isTrue);
  });

  test('all-successful empty sources return a successful empty page', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      firestore: _EmptyFirestore(),
      settings: settings,
      favourites: _CountingFavourites(),
    );

    final result = await repository.fetch(_firstPage);

    expect(result.isSuccess, isTrue);
    expect(result.data!.items, isEmpty);
    expect(result.data!.hasMore, isFalse);
  });

  test('Prism source failure preserves healthy cache if providers return empty', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    final _OneWallFirestore firestore = _OneWallFirestore();
    final _ToggleWallhaven wallhaven = _ToggleWallhaven();
    final _TogglePexels pexels = _TogglePexels();
    final _MemoryFeedCache cache = _MemoryFeedCache();
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      firestore: firestore,
      cache: cache,
      settings: settings,
      wallhaven: wallhaven,
      pexels: pexels,
      favourites: _CountingFavourites(),
    );
    final first = await repository.fetch(_firstPage);
    expect(_itemIds(first.data!.items), <String>['visible-doc', 'wall-doc']);

    firestore.fail = true;
    final fallback = await repository.fetch(_firstPage);

    expect(_itemIds(fallback.data!.items), <String>['visible-doc', 'wall-doc']);
    expect((cache.snapshot!.payload! as Map)['items'], hasLength(2));
  });

  test('failed refresh preserves cache when its only candidates are hidden', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    final _OneWallFirestore firestore = _OneWallFirestore();
    final _ToggleWallhaven wallhaven = _ToggleWallhaven();
    final _TogglePexels pexels = _TogglePexels();
    final _MemoryFeedCache cache = _MemoryFeedCache();
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      firestore: firestore,
      cache: cache,
      settings: settings,
      wallhaven: wallhaven,
      pexels: pexels,
      favourites: _CountingFavourites(),
    );
    final first = await repository.fetch(_firstPage);
    expect(_itemIds(first.data!.items), <String>['visible-doc', 'wall-doc']);
    await repository.lessLikeThis(first.data!.items.firstWhere((item) => item.id == 'wall-doc'));

    firestore.onlyHiddenFresh = true;
    wallhaven.fail = true;
    pexels.fail = true;
    final fallback = await repository.fetch(_firstPage);

    expect(_itemIds(fallback.data!.items), <String>['visible-doc']);
    expect((cache.snapshot!.payload! as Map)['items'], hasLength(2));
  });

  test('hidden cached item stays hidden during offline cache fallback', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    final _OneWallFirestore firestore = _OneWallFirestore();
    final _ToggleWallhaven wallhaven = _ToggleWallhaven();
    final _TogglePexels pexels = _TogglePexels();
    final _MemoryFeedCache cache = _MemoryFeedCache();
    final _EmptyBlocks blocks = _EmptyBlocks();
    final TasteSignalStore signals = TasteSignalStore(settings);
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = PersonalizedFeedRepositoryImpl(
      firestore,
      cache,
      settings,
      wallhaven,
      pexels,
      blocks,
      _CountingFavourites(),
      signals,
      FeedImpressionStore(settings),
    );
    final first = await repository.fetch(_firstPage);
    expect(_itemIds(first.data!.items), <String>['visible-doc', 'wall-doc']);
    final FeedItemEntity hidden = first.data!.items.firstWhere((item) => item.id == 'wall-doc');
    await repository.lessLikeThis(hidden);

    blocks.failNext = true;
    final fallback = await repository.fetch(_firstPage);

    expect(_itemIds(fallback.data!.items), <String>['visible-doc']);
    expect((cache.snapshot!.payload! as Map)['items'], hasLength(2));
  });

  for (final String wallpaperKey in <String>['wall', 'wallpaper']) {
    test('offline fallback reads the $wallpaperKey cache format from a merge parent', () async {
      final cache = _MemoryFeedCache()
        ..snapshot = FeedSnapshot(
          cachedAtUtc: DateTime.now().toUtc(),
          ttlHours: 2,
          payload: <String, Object?>{
            'items': <Object?>[
              <String, Object?>{
                'type': 'prism',
                'id': 'cached',
                wallpaperKey: <String, Object?>{
                  'core': <String, Object?>{
                    'id': 'cached',
                    'source': 'prism',
                    'fullUrl': 'https://example.com/cached.jpg',
                    'thumbnailUrl': 'https://example.com/cached-thumb.jpg',
                  },
                  'tags': <String>['space'],
                  'firestoreDocumentId': 'cached-doc',
                },
              },
            ],
          },
        );
      final repository = _repository(
        firestore: _OfflineFirestore(),
        wallhaven: _OfflineWallhaven(),
        pexels: _OfflinePexels(),
        cache: cache,
        favourites: _CountingFavourites(),
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
      );

      final result = await repository.fetch(_firstPage);

      expect(_itemIds(result.data?.items ?? const <FeedItemEntity>[]), <String>['cached']);
      final wall = (result.data!.items.single as PrismFeedItem).wallpaper;
      expect(wall.fullUrl, 'https://example.com/cached.jpg');
      expect(wall.tags, <String>['space']);
      expect(wall.firestoreDocumentId, 'cached-doc');
    });
  }

  test('cache fallback stops paging after cached items are exhausted', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    final _OneWallFirestore firestore = _OneWallFirestore();
    final _ToggleWallhaven wallhaven = _ToggleWallhaven();
    final _TogglePexels pexels = _TogglePexels();
    final _MemoryFeedCache cache = _MemoryFeedCache();
    final _EmptyBlocks blocks = _EmptyBlocks();
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = PersonalizedFeedRepositoryImpl(
      firestore,
      cache,
      settings,
      wallhaven,
      pexels,
      blocks,
      _CountingFavourites(),
      TasteSignalStore(settings),
      FeedImpressionStore(settings),
    );
    final first = await repository.fetch(_firstPage);
    expect(_itemIds(first.data!.items), <String>['visible-doc', 'wall-doc']);
    blocks.failNext = true;

    final exhausted = await repository.fetch(
      FetchPersonalizedFeedRequest(
        page: 2,
        refresh: false,
        seenKeys: const <String>[],
        existingItems: first.data!.items,
      ),
    );
    expect(exhausted.data!.items, isEmpty);
    expect(exhausted.data!.hasMore, isFalse);
  });

  test('user profile lookup failure does not block public feed sources', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    final _OneWallFirestore firestore = _OneWallFirestore()..failUserDoc = true;
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      firestore: firestore,
      settings: settings,
      favourites: _CountingFavourites(),
    );

    final result = await repository.fetch(_firstPage);

    expect(_itemIds(result.data?.items ?? const <FeedItemEntity>[]), <String>['visible-doc', 'wall-doc']);
  });
}

const FetchPersonalizedFeedRequest _firstPage = FetchPersonalizedFeedRequest(
  page: 1,
  refresh: true,
  seenKeys: <String>[],
  existingItems: <FeedItemEntity>[],
);

PersonalizedFeedRepository _repository({
  required FavouriteWallsRepository favourites,
  required FirestoreClient firestore,
  required SettingsLocalDataSource settings,
  WallhavenWallpaperRepository? wallhaven,
  PexelsWallpaperRepository? pexels,
  FeedCacheLocalDataSource? cache,
  TasteSignalStore? tasteSignals,
}) {
  return PersonalizedFeedRepositoryImpl(
    firestore,
    cache ?? _EmptyFeedCache(),
    settings,
    wallhaven ?? _EmptyWallhaven(),
    pexels ?? _EmptyPexels(),
    _EmptyBlocks(),
    favourites,
    tasteSignals ?? TasteSignalStore(settings),
    FeedImpressionStore(settings),
  );
}

List<String> _itemIds(List<FeedItemEntity> items) => items.map((item) => item.id).toList()..sort();

PrismFavouriteWall _favourite(String id) => PrismFavouriteWall(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: 'https://example.com/$id-thumb.jpg',
      category: 'Nature',
    ),
    tags: const <String>['nature'],
  ),
);
