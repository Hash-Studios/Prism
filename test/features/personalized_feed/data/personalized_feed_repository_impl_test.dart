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
import 'package:Prism/features/category_feed/data/feed_item_cache_codec.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_walls_repository.dart';
import 'package:Prism/features/personalized_feed/data/feed_impression_store.dart';
import 'package:Prism/features/personalized_feed/data/personalized_feed_repository_impl.dart';
import 'package:Prism/features/personalized_feed/data/personalized_ranking_service.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
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

class _PendingFreshFirestore extends Fake implements FirestoreClient {
  final Completer<void> ready = Completer<void>();
  final Completer<void> freshStarted = Completer<void>();
  int _freshCalls = 0;

  static const Map<String, dynamic> _oldWall = <String, dynamic>{
    'wallpaper_url': 'https://example.com/wall.jpg',
    'wallpaper_thumb': 'https://example.com/thumb.jpg',
    'wallpaper_provider': 'prism',
    'review': true,
    'email': 'creator@example.com',
    'createdAt': '2026-09-01T00:00:00Z',
  };
  static const Map<String, dynamic> _newWall = <String, dynamic>{
    'wallpaper_url': 'https://example.com/new-wall.jpg',
    'wallpaper_thumb': 'https://example.com/new-thumb.jpg',
    'wallpaper_provider': 'prism',
    'review': true,
    'email': 'new-creator@example.com',
    'createdAt': '2026-09-01T00:00:00Z',
  };

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    if (spec.sourceTag != 'personalized.fresh') {
      throw StateError('offline');
    }
    _freshCalls++;
    if (_freshCalls == 1) {
      freshStarted.complete();
      await ready.future;
      return <T>[map(_oldWall, 'old-wall')];
    }
    return <T>[map(_newWall, 'new-wall')];
  }

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async => null;
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
    bool portraitOnly = true,
    String? minResolution,
    String? sorting,
  }) async => Result.success(<WallhavenWallpaper>[]);
}

class _HangingWallhaven extends Fake implements WallhavenWallpaperRepository {
  @override
  Future<Result<List<WallhavenWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int categories = 100,
    int purity = 100,
    int startPage = 1,
    String? paginationKey,
    bool portraitOnly = true,
    String? minResolution,
    String? sorting,
  }) => Completer<Result<List<WallhavenWallpaper>>>().future;
}

class _RecordingFirestore extends _EmptyFirestore {
  final List<String> sourceTags = <String>[];

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    sourceTags.add(spec.sourceTag);
    return <T>[];
  }
}

class _EmptyPexels extends Fake implements PexelsWallpaperRepository {
  @override
  Future<Result<List<PexelsWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int startPage = 1,
    String? paginationKey,
    bool portraitOnly = true,
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
    bool portraitOnly = true,
    String? minResolution,
    String? sorting,
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
    bool portraitOnly = true,
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
    bool portraitOnly = true,
    String? minResolution,
    String? sorting,
  }) async => Result.error(const UnknownFailure('offline'));
}

class _OfflinePexels extends Fake implements PexelsWallpaperRepository {
  @override
  Future<Result<List<PexelsWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int startPage = 1,
    String? paginationKey,
    bool portraitOnly = true,
  }) async => Result.error(const UnknownFailure('offline'));
}

class _EmptyBlocks extends Fake implements UserBlockRepository {
  bool failNext = false;
  Set<String> cached = <String>{};
  bool hangOnWait = false;

  @override
  Set<String> get cachedBlockedCreatorEmails => cached;

  @override
  Future<Set<String>> getBlockedCreatorEmails({bool waitForInitialLoad = false}) async {
    if (hangOnWait && waitForInitialLoad) {
      return Completer<Set<String>>().future;
    }
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

class _PendingRecordTasteSignalStore extends TasteSignalStore {
  _PendingRecordTasteSignalStore(super.settingsLocal);

  final Completer<void> recordStarted = Completer<void>();
  final Completer<void> resumeRecord = Completer<void>();

  @override
  Future<void> record(TasteSignal signal) async {
    await super.record(signal);
    recordStarted.complete();
    await resumeRecord.future;
  }
}

PrismUsersV2 _signedInUser({List<String> following = const <String>[]}) {
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
    following: following,
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

  test('less-like-this does not hide a wall after sign-out clears its pending signal', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    final _PendingRecordTasteSignalStore signals = _PendingRecordTasteSignalStore(settings);
    final FeedImpressionStore impressions = FeedImpressionStore(settings);
    final PersonalizedFeedRepository repository = _repository(
      firestore: _EmptyFirestore(),
      settings: settings,
      favourites: _CountingFavourites(),
      tasteSignals: signals,
      impressions: impressions,
    );
    app_state.prismUser = _signedInUser();
    const WallhavenWallpaper wall = WallhavenWallpaper(
      core: WallpaperCore(
        id: 'wall',
        source: WallpaperSource.wallhaven,
        fullUrl: 'https://example.com/wall.jpg',
        thumbnailUrl: 't',
        category: 'general',
      ),
    );
    final Future<void> pending = repository.lessLikeThis(const WallhavenFeedItem(id: 'wall', wallpaper: wall));
    await signals.recordStarted.future;

    app_state.prismUser = app_constants.createGuestPrismUser();
    await signals.clear(allowReseed: true);
    await impressions.clear();
    signals.resumeRecord.complete();
    await pending;

    expect(impressions.recentShows(DateTime.now().toUtc()), isEmpty);
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

  test('sign-out clear invalidates a pending favourite seed even when reseeding is allowed', () async {
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

    await repository.fetch(_firstPage).timeout(const Duration(seconds: 2));
    await signals.clear(allowReseed: true);
    expect(signals.isSeeded, isFalse);

    favourites.completer.complete(Result.success(<FavouriteWallEntity>[_favourite('old-user-favourite')]));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(signals.read(), isEmpty);
    expect(signals.isSeeded, isFalse);
  });

  test('a feed request already in progress cannot restore impressions after sign-out clear', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    final FeedImpressionStore impressions = FeedImpressionStore(settings);
    final TasteSignalStore signals = TasteSignalStore(settings);
    final _PendingFreshFirestore firestore = _PendingFreshFirestore();
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      favourites: _CountingFavourites(),
      firestore: firestore,
      settings: settings,
      tasteSignals: signals,
      impressions: impressions,
    );
    final Future<Result<PersonalizedFeedPage>> pending = repository.fetch(_firstPage);
    await firestore.freshStarted.future;

    app_state.prismUser = app_constants.createGuestPrismUser();
    await signals.clear(allowReseed: true);
    await impressions.clear();
    final Result<PersonalizedFeedPage> newSessionResult = await repository.fetch(_firstPage);
    firestore.ready.complete();
    final Result<PersonalizedFeedPage> oldSessionResult = await pending;

    expect(newSessionResult.data?.items.map((item) => item.id), <String>['new-wall']);
    expect(oldSessionResult.isFailure, isTrue);
    expect(impressions.recentShows(DateTime.now().toUtc()), isEmpty);
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

  test('a failed later page is an error, not the end of the feed', () async {
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
    firestore.fail = true;

    final failed = await repository.fetch(
      FetchPersonalizedFeedRequest(
        page: 2,
        refresh: false,
        seenKeys: const <String>[],
        existingItems: first.data!.items,
      ),
    );
    expect(failed.isFailure, isTrue);

    final retry = await repository.fetch(_firstPage);
    expect(retry.isFailure, isFalse, reason: 'page one still falls back to the cache while the network is down');
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

  test('a slow source cannot hold the feed past its timeout', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set('onboarding_v2_interests', 'Photography');
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      firestore: _OneWallFirestore(),
      wallhaven: _HangingWallhaven(),
      settings: settings,
      favourites: _CountingFavourites(),
    );

    final result = await repository.fetch(_firstPage).timeout(const Duration(seconds: 9));

    expect(_itemIds(result.data?.items ?? const <FeedItemEntity>[]), <String>['visible-doc', 'wall-doc']);
  });

  test('following is read from the session on every fetch, not only on refresh', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    final _RecordingFirestore firestore = _RecordingFirestore();
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      firestore: firestore,
      settings: settings,
      favourites: _CountingFavourites(),
    );

    await repository.fetch(_firstPage);
    expect(firestore.sourceTags, isNot(contains('personalized.creator_chunk_1')));

    app_state.prismUser = _signedInUser(following: const <String>['creator@example.com']);
    await repository.fetch(
      const FetchPersonalizedFeedRequest(
        page: 2,
        refresh: false,
        seenKeys: <String>[],
        existingItems: <FeedItemEntity>[],
      ),
    );

    expect(firestore.sourceTags, contains('personalized.creator_chunk_1'));
  });

  test('a fetch does not count wallpapers as shown. The screen reports the tiles it builds', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    final FeedImpressionStore impressions = FeedImpressionStore(settings);
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      firestore: _OneWallFirestore(),
      settings: settings,
      favourites: _CountingFavourites(),
      impressions: impressions,
    );

    await repository.fetch(_firstPage);
    expect(impressions.recentShows(DateTime.now().toUtc()), isEmpty);

    await repository.recordShown(<String>['https://example.com/wall.jpg']);
    expect(impressions.recentShows(DateTime.now().toUtc()), <String, int>{'https://example.com/wall.jpg': 1});
  });

  test('the cached list is capped at 48 items', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    final _MemoryFeedCache cache = _MemoryFeedCache();
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      firestore: _OneWallFirestore(),
      cache: cache,
      settings: settings,
      favourites: _CountingFavourites(),
    );

    await repository.fetch(
      FetchPersonalizedFeedRequest(
        page: 2,
        refresh: false,
        seenKeys: const <String>[],
        existingItems: <FeedItemEntity>[for (int i = 0; i < 60; i++) _prismItem('old-$i')],
      ),
    );

    expect((cache.snapshot!.payload! as Map)['items'], hasLength(48));
  });

  test('a page past the second does not rewrite the cache', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    final _MemoryFeedCache cache = _MemoryFeedCache();
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      firestore: _OneWallFirestore(),
      cache: cache,
      settings: settings,
      favourites: _CountingFavourites(),
    );

    await repository.fetch(
      const FetchPersonalizedFeedRequest(
        page: 3,
        refresh: false,
        seenKeys: <String>[],
        existingItems: <FeedItemEntity>[],
      ),
    );

    expect(cache.snapshot, isNull);
  });

  group('readCached', () {
    FeedSnapshot snapshot(List<FeedItemEntity> items, {DateTime? at, String? filters}) => FeedSnapshot(
      cachedAtUtc: at ?? DateTime.now().toUtc(),
      ttlHours: 2,
      payload: <String, Object?>{'filters': ?filters, 'items': items.map(encodeFeedItem).toList()},
    );

    test('is null when nothing is cached', () async {
      final PersonalizedFeedRepository repository = _repository(
        firestore: _EmptyFirestore(),
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );

      expect(await repository.readCached(), isNull);
    });

    test('returns at most 24 items with their keys, without waiting for the block list', () async {
      app_state.prismUser = _signedInUser();
      final _EmptyBlocks blocks = _EmptyBlocks()..hangOnWait = true;
      final PersonalizedFeedRepository repository = _repository(
        firestore: _EmptyFirestore(),
        cache: _MemoryFeedCache()
          ..snapshot = snapshot(<FeedItemEntity>[for (int i = 0; i < 40; i++) _prismItem('c$i')]),
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: blocks,
      );

      final PersonalizedFeedPage? page = await repository.readCached().timeout(const Duration(seconds: 2));

      expect(page!.items, hasLength(24));
      expect(page.usedKeys, hasLength(24));
      expect(page.isStale, isFalse);
    });

    test('drops blocked creators', () async {
      app_state.prismUser = _signedInUser();
      final PersonalizedFeedRepository repository = _repository(
        firestore: _EmptyFirestore(),
        cache: _MemoryFeedCache()
          ..snapshot = snapshot(<FeedItemEntity>[
            _prismItem('keep', email: 'kept@example.com'),
            _prismItem('drop', email: 'blocked@example.com'),
          ]),
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: _EmptyBlocks()..cached = <String>{'blocked@example.com'},
      );

      expect(_itemIds((await repository.readCached())!.items), <String>['keep']);
    });

    test('marks a snapshot older than the cache lifetime as stale', () async {
      app_state.prismUser = _signedInUser();
      final PersonalizedFeedRepository repository = _repository(
        firestore: _EmptyFirestore(),
        cache: _MemoryFeedCache()
          ..snapshot = snapshot(<FeedItemEntity>[
            _prismItem('old'),
          ], at: DateTime.now().toUtc().subtract(const Duration(hours: 5))),
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );

      expect((await repository.readCached())!.isStale, isTrue);
    });

    test('keeps hidden walls out', () async {
      final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
      app_state.prismUser = _signedInUser();
      final FeedImpressionStore impressions = FeedImpressionStore(settings);
      final FeedItemEntity hidden = _prismItem('hidden');
      await impressions.hide(PersonalizedRankingService.canonicalKey(hidden), DateTime.now().toUtc());
      final PersonalizedFeedRepository repository = _repository(
        firestore: _EmptyFirestore(),
        cache: _MemoryFeedCache()..snapshot = snapshot(<FeedItemEntity>[hidden, _prismItem('shown')]),
        settings: settings,
        favourites: _CountingFavourites(),
        impressions: impressions,
      );

      expect(_itemIds((await repository.readCached())!.items), <String>['shown']);
    });

    test('drops Wallhaven items cached under other content filters', () async {
      final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
      app_state.prismUser = _signedInUser();
      final List<FeedItemEntity> items = <FeedItemEntity>[_prismItem('prism'), _wallhavenItem('wh')];
      final _MemoryFeedCache cache = _MemoryFeedCache()..snapshot = snapshot(items, filters: '100.100');
      final PersonalizedFeedRepository repository = _repository(
        firestore: _EmptyFirestore(),
        cache: cache,
        settings: settings,
        favourites: _CountingFavourites(),
      );
      expect(_itemIds((await repository.readCached())!.items), <String>['prism', 'wh']);

      await settings.set('WHpurity', 110);

      expect(_itemIds((await repository.readCached())!.items), <String>['prism']);
    });

    test('treats a cache without a filter stamp as the default filters', () async {
      final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
      app_state.prismUser = _signedInUser();
      await settings.set('WHcategories', 110);
      final PersonalizedFeedRepository repository = _repository(
        firestore: _EmptyFirestore(),
        cache: _MemoryFeedCache()..snapshot = snapshot(<FeedItemEntity>[_prismItem('prism'), _wallhavenItem('wh')]),
        settings: settings,
        favourites: _CountingFavourites(),
      );

      expect(_itemIds((await repository.readCached())!.items), <String>['prism']);
    });

    test('a cache written by a fetch carries the content filters', () async {
      final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
      await settings.set('WHpurity', 110);
      final _MemoryFeedCache cache = _MemoryFeedCache();
      app_state.prismUser = _signedInUser();
      final PersonalizedFeedRepository repository = _repository(
        firestore: _OneWallFirestore(),
        cache: cache,
        settings: settings,
        favourites: _CountingFavourites(),
      );

      await repository.fetch(_firstPage);

      expect((cache.snapshot!.payload! as Map)['filters'], '100.110');
    });
  });

  group('undoLessLikeThis', () {
    test('shows a hidden wall again', () async {
      final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
      final FeedImpressionStore impressions = FeedImpressionStore(settings);
      final PersonalizedFeedRepository repository = _repository(
        firestore: _EmptyFirestore(),
        settings: settings,
        favourites: _CountingFavourites(),
        impressions: impressions,
      );
      final FeedItemEntity item = _prismItem('x');

      await repository.lessLikeThis(item);
      expect(impressions.recentShows(DateTime.now().toUtc()), isNotEmpty);
      await repository.undoLessLikeThis(item);

      expect(impressions.recentShows(DateTime.now().toUtc()), isEmpty);
    });
  });

  group('fetchFollowing', () {
    test('returns the followed creators walls and reports that more may follow', () async {
      app_state.prismUser = _signedInUser(following: const <String>['a@example.com']);
      final _FollowingFirestore firestore = _FollowingFirestore(rows: 12);
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );

      final result = await repository.fetchFollowing(page: 1);

      expect(result.data!.items, hasLength(12));
      expect(result.data!.hasMore, isTrue);
      expect(firestore.limits, <int>[12]);
    });

    test('has no more pages when the creator has fewer walls than the page limit', () async {
      app_state.prismUser = _signedInUser(following: const <String>['a@example.com']);
      final PersonalizedFeedRepository repository = _repository(
        firestore: _FollowingFirestore(rows: 3),
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );

      final result = await repository.fetchFollowing(page: 1);

      expect(result.data!.items, hasLength(3));
      expect(result.data!.hasMore, isFalse);
    });

    test('is empty without a query when the user follows nobody', () async {
      app_state.prismUser = _signedInUser();
      final _FollowingFirestore firestore = _FollowingFirestore(rows: 3);
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );

      final result = await repository.fetchFollowing(page: 1);

      expect(result.data!.items, isEmpty);
      expect(firestore.limits, isEmpty);
    });

    test('hides blocked creators and reports a failed read', () async {
      app_state.prismUser = _signedInUser(following: const <String>['a@example.com']);
      final _FollowingFirestore firestore = _FollowingFirestore(rows: 2, email: 'blocked@example.com');
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: _BlockingBlocks(<String>{'blocked@example.com'}),
      );
      expect((await repository.fetchFollowing(page: 1)).data!.items, isEmpty);

      firestore.fail = true;
      expect((await repository.fetchFollowing(page: 1)).isFailure, isTrue);
    });
  });

  group('fetchPopular', () {
    test('resolves the popular list in order and drops walls that no longer exist', () async {
      final _PopularFirestore firestore = _PopularFirestore(
        popularIds: <String>['CCC', 'AAA', 'ZZZ', 'BBB'],
        walls: <String>['AAA', 'BBB', 'CCC'],
      );
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );

      final result = await repository.fetchPopular();

      expect(result.data!.items.map((item) => item.id), <String>['CCC', 'AAA', 'BBB']);
      expect(result.data!.hasMore, isFalse);
      expect(firestore.sourceTags, containsAll(<String>['popular.current', 'popular.walls']));
      expect(firestore.sourceTags, isNot(contains('popular.stats')));
    });

    test('falls back to the most viewed walls when the list is missing', () async {
      final _PopularFirestore firestore = _PopularFirestore(
        statsIds: <String>['BBB', 'AAA'],
        walls: <String>['AAA', 'BBB'],
      );
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );

      final result = await repository.fetchPopular();

      expect(result.data!.items.map((item) => item.id), <String>['BBB', 'AAA']);
      expect(firestore.sourceTags, contains('popular.stats'));
    });

    test('falls back when the popular list cannot be read', () async {
      final _PopularFirestore firestore = _PopularFirestore(
        popularFails: true,
        statsIds: <String>['AAA'],
        walls: <String>['AAA'],
      );
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );

      expect((await repository.fetchPopular()).data!.items.map((item) => item.id), <String>['AAA']);
    });

    test('looks walls up ten ids at a time and upper-cases the ids', () async {
      final List<String> ids = <String>[for (int i = 0; i < 25; i++) 'W${i.toString().padLeft(2, '0')}'];
      final _PopularFirestore firestore = _PopularFirestore(
        popularIds: ids.map((id) => id.toLowerCase()).toList(),
        walls: ids,
      );
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );

      final result = await repository.fetchPopular();

      expect(result.data!.items, hasLength(25));
      expect(firestore.whereInSizes, <int>[10, 10, 5]);
    });

    test('reports a failure when no source answers', () async {
      final PersonalizedFeedRepository repository = _repository(
        firestore: _OfflineFirestore(),
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );

      expect((await repository.fetchPopular()).isFailure, isTrue);
    });
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
  FeedImpressionStore? impressions,
  UserBlockRepository? blocks,
}) {
  return PersonalizedFeedRepositoryImpl(
    firestore,
    cache ?? _EmptyFeedCache(),
    settings,
    wallhaven ?? _EmptyWallhaven(),
    pexels ?? _EmptyPexels(),
    blocks ?? _EmptyBlocks(),
    favourites,
    tasteSignals ?? TasteSignalStore(settings),
    impressions ?? FeedImpressionStore(settings),
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

FeedItemEntity _prismItem(String id, {String email = 'creator@example.com'}) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: 'https://example.com/$id-thumb.jpg',
      authorEmail: email,
    ),
  ),
);

FeedItemEntity _wallhavenItem(String id) => FeedItemEntity.wallhaven(
  id: id,
  wallpaper: WallhavenWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.wallhaven,
      fullUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: 'https://example.com/$id-thumb.jpg',
    ),
  ),
);

class _BlockingBlocks extends _EmptyBlocks {
  _BlockingBlocks(Set<String> blocked) {
    cached = blocked;
  }

  @override
  Future<Set<String>> getBlockedCreatorEmails({bool waitForInitialLoad = false}) async => cached;
}

/// Answers the creator query with [rows] walls and records the limit it was asked for.
class _FollowingFirestore extends _EmptyFirestore {
  _FollowingFirestore({required this.rows, this.email = 'a@example.com'});

  final int rows;
  final String email;
  bool fail = false;
  final List<int> limits = <int>[];

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    if (!spec.sourceTag.startsWith('personalized.creator_chunk_')) {
      return <T>[];
    }
    if (fail) {
      throw StateError('offline');
    }
    limits.add(spec.limit!);
    return <T>[
      for (int i = 0; i < rows; i++)
        map(<String, dynamic>{
          'id': 'W$i',
          'wallpaper_url': 'https://example.com/w$i.jpg',
          'wallpaper_thumb': 'https://example.com/w$i-thumb.jpg',
          'wallpaper_provider': 'prism',
          'review': true,
          'email': email,
          'createdAt': '2026-09-01T00:00:00Z',
        }, 'doc$i'),
    ];
  }
}

class _PopularFirestore extends _EmptyFirestore {
  _PopularFirestore({
    this.popularIds = const <String>[],
    this.statsIds = const <String>[],
    this.popularFails = false,
    this.walls = const <String>[],
  });

  final List<String> popularIds;
  final List<String> statsIds;
  final bool popularFails;
  final List<String> walls;
  final List<String> sourceTags = <String>[];
  final List<int> whereInSizes = <int>[];

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async {
    sourceTags.add(sourceTag);
    if (popularFails) {
      throw StateError('permission-denied');
    }
    return popularIds.isEmpty ? null : map(<String, dynamic>{'wallIds': popularIds}, id);
  }

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    sourceTags.add(spec.sourceTag);
    if (spec.sourceTag == 'popular.stats') {
      return <T>[
        for (final String id in statsIds) map(<String, dynamic>{'views': 1}, id),
      ];
    }
    final List<Object?> wanted = spec.filters.firstWhere((f) => f.field == 'id').value! as List<Object?>;
    whereInSizes.add(wanted.length);
    return <T>[
      for (final String id in walls)
        if (wanted.contains(id))
          map(<String, dynamic>{
            'id': id,
            'wallpaper_url': 'https://example.com/$id.jpg',
            'wallpaper_thumb': 'https://example.com/$id-thumb.jpg',
            'wallpaper_provider': 'prism',
            'review': true,
            'email': 'creator@example.com',
          }, 'doc-$id'),
    ];
  }
}
