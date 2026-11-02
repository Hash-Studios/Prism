// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/auth/badge_model.dart';
import 'package:Prism/auth/transaction_model.dart';
import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
import 'package:Prism/features/category_feed/data/feed_item_cache_codec.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_walls_repository.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/personalized_feed/data/feed_impression_store.dart';
import 'package:Prism/features/personalized_feed/data/personalized_feed_repository_impl.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/logger/app_logger.dart';
import 'package:fake_async/fake_async.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_remote_config_platform_interface/firebase_remote_config_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';

class _FakeFirebaseRemoteConfigPlatform extends FirebaseRemoteConfigPlatform {
  String interests = '';

  @override
  FirebaseRemoteConfigPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseRemoteConfigPlatform setInitialValues({required Map<Object?, Object?> remoteConfigValues}) => this;

  @override
  String getString(String key) => key == app_constants.personalizedInterestsRemoteConfigKey ? interests : '';
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
    'creatorUid': 'creator-id',
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

class _AnimeWallFirestore extends _OneWallFirestore {
  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async =>
      <T>[
        map(<String, dynamic>{
          ..._OneWallFirestore._wall,
          'wallpaper_url': 'https://example.com/anime.jpg',
          'category': 'Anime',
        }, 'anime-doc'),
        map(<String, dynamic>{
          ..._OneWallFirestore._wall,
          'wallpaper_url': 'https://example.com/visible.jpg',
        }, 'visible-doc'),
      ];
}

class _AiWallFirestore extends _OneWallFirestore {
  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async =>
      <T>[
        map(<String, dynamic>{
          ..._OneWallFirestore._wall,
          'wallpaper_url': 'https://example.com/ai.jpg',
          'isAiGenerated': true,
        }, 'ai-doc'),
        map(<String, dynamic>{
          ..._OneWallFirestore._wall,
          'wallpaper_url': 'https://example.com/visible.jpg',
        }, 'visible-doc'),
      ];
}

class _GatedWallsFirestore extends _CountingWallsFirestore {
  final Completer<void> gate = Completer<void>();

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    await gate.future;
    return super.query(spec, map);
  }
}

class _CountingWallsFirestore extends _OneWallFirestore {
  final List<String> sourceTags = <String>[];

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) {
    sourceTags.add(spec.sourceTag);
    return super.query(spec, map);
  }
}

class _StaleProfileFirestore extends _OneWallFirestore {
  String interest = 'Nature';

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic>, String) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async => map(<String, dynamic>{
    'interestCategories': <String>[if (preferCacheFirst) 'Nature' else interest],
  }, id);
}

class _SlowWallsFirestore extends _OneWallFirestore {
  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    if (spec.sourceTag == 'personalized.fresh') {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return super.query(spec, map);
  }
}

class _PendingFreshFirestore extends Fake implements FirestoreClient {
  final Completer<void> ready = Completer<void>();
  final Completer<void> freshStarted = Completer<void>();
  final List<String> sourceTags = <String>[];
  int _freshCalls = 0;

  static const Map<String, dynamic> _oldWall = <String, dynamic>{
    'wallpaper_url': 'https://example.com/wall.jpg',
    'wallpaper_thumb': 'https://example.com/thumb.jpg',
    'wallpaper_provider': 'prism',
    'review': true,
    'email': 'creator@example.com',
    'creatorUid': 'creator-id',
    'createdAt': '2026-09-01T00:00:00Z',
  };
  static const Map<String, dynamic> _newWall = <String, dynamic>{
    'wallpaper_url': 'https://example.com/new-wall.jpg',
    'wallpaper_thumb': 'https://example.com/new-thumb.jpg',
    'wallpaper_provider': 'prism',
    'review': true,
    'email': 'new-creator@example.com',
    'creatorUid': 'new-creator-id',
    'createdAt': '2026-09-01T00:00:00Z',
  };

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    sourceTags.add(spec.sourceTag);
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

class _SlowOfflineCatalog extends OfflineWallpaperCatalog {
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<void> remember(Iterable<FeedItemEntity> items) {
    if (!started.isCompleted) started.complete();
    return release.future;
  }
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

class _CountingFeedCache extends _MemoryFeedCache {
  final List<String> scopes = <String>[];

  @override
  Future<FeedSnapshot?> read({required String source, required String scope}) {
    scopes.add(scope);
    return super.read(source: source, scope: scope);
  }
}

class _DelayedFeedCache extends _MemoryFeedCache {
  final Completer<void> release = Completer<void>();

  @override
  Future<FeedSnapshot?> read({required String source, required String scope}) async {
    await release.future;
    return super.read(source: source, scope: scope);
  }
}

class _FailingFeedCache extends _MemoryFeedCache {
  @override
  Future<FeedSnapshot?> read({required String source, required String scope}) =>
      Future<FeedSnapshot?>.error(StateError('unreadable cache'));
}

class _RecoveringFeedCache extends _MemoryFeedCache {
  bool failRead = true;

  @override
  Future<FeedSnapshot?> read({required String source, required String scope}) =>
      failRead ? Future<FeedSnapshot?>.error(StateError('unreadable cache')) : super.read(source: source, scope: scope);
}

class _WriteGatedFeedCache extends _MemoryFeedCache {
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();
  int writes = 0;

  @override
  Future<void> write({
    required String source,
    required String scope,
    required Object? payload,
    required int ttlHours,
  }) async {
    if (writes++ == 0) {
      started.complete();
      await release.future;
    }
    await super.write(source: source, scope: scope, payload: payload, ttlHours: ttlHours);
  }
}

class _RecordingOfflineCatalog extends OfflineWallpaperCatalog {
  final List<FeedItemEntity> remembered = <FeedItemEntity>[];

  @override
  Future<void> remember(Iterable<FeedItemEntity> items) async => remembered.addAll(items);
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
    String? colors,
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
    String? colors,
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
    String? color,
  }) async => Result.success(<PexelsWallpaper>[]);
}

class _InterestWallhaven extends _EmptyWallhaven {
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
    String? colors,
  }) async => Result.success(<WallhavenWallpaper>[
    WallhavenWallpaper(
      core: WallpaperCore(
        id: categoryName,
        source: WallpaperSource.wallhaven,
        fullUrl: 'https://example.com/$categoryName.jpg',
        thumbnailUrl: 'https://example.com/$categoryName-thumb.jpg',
        category: 'general',
      ),
    ),
  ]);
}

class _ToggleWallhaven extends Fake implements WallhavenWallpaperRepository {
  bool fail = false;
  final List<String> queries = <String>[];

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
    String? colors,
  }) async {
    queries.add(categoryName);
    return fail ? Result.error(const UnknownFailure('offline')) : Result.success(<WallhavenWallpaper>[]);
  }
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
    String? color,
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
    String? colors,
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
    String? color,
  }) async => Result.error(const UnknownFailure('offline'));
}

class _TimedOutFirestore extends Fake implements FirestoreClient {
  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async =>
      throw TimeoutException('No confirmed server snapshot for ${spec.sourceTag}.');

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async => null;
}

class _HangingPexels extends Fake implements PexelsWallpaperRepository {
  @override
  Future<Result<List<PexelsWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int startPage = 1,
    String? paginationKey,
    bool portraitOnly = true,
    String? color,
  }) => Completer<Result<List<PexelsWallpaper>>>().future;
}

class _EmptyBlocks extends Fake implements UserBlockRepository {
  bool failNext = false;
  bool failCachedRead = false;
  Set<String> cached = <String>{};
  bool hangOnWait = false;
  Duration loadDelay = Duration.zero;
  Set<String> loaded = <String>{};

  @override
  BlockedCreators get blockedCreators {
    if (failCachedRead) {
      failCachedRead = false;
      throw StateError('blocked list unavailable');
    }
    return KnownBlockedCreators(cached);
  }

  @override
  Future<BlockedCreators> loadBlockedCreators() async {
    if (loadDelay > Duration.zero) {
      await Future<void>.delayed(loadDelay);
      return KnownBlockedCreators(loaded);
    }
    if (hangOnWait) {
      return Completer<BlockedCreators>().future;
    }
    if (failNext) {
      failNext = false;
      throw StateError('offline');
    }
    return KnownBlockedCreators(cached);
  }
}

class _PendingBlocks extends _EmptyBlocks {
  final Completer<BlockedCreators> initial = Completer<BlockedCreators>();

  @override
  Future<BlockedCreators> loadBlockedCreators() => initial.future;
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

class _SeededFavourites extends _CountingFavourites {
  @override
  Future<Result<List<FavouriteWallEntity>>> fetchFavourites({required String userId}) async {
    calls++;
    return Result.success(<FavouriteWallEntity>[_favourite('seeded')]);
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

PrismUsersV2 _signedInUser({List<String> following = const <String>[], String id = 'feed-test-user'}) {
  final String now = DateTime.now().toUtc().toIso8601String();
  return PrismUsersV2(
    username: '',
    email: '',
    id: id,
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
  late _FakeFirebaseRemoteConfigPlatform remoteConfig;

  setUp(TasteSignal.clearRememberedFeedTerms);
  tearDown(TasteSignal.clearRememberedFeedTerms);

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    remoteConfig = _FakeFirebaseRemoteConfigPlatform();
    FirebaseRemoteConfigPlatform.instance = remoteConfig;
  });

  test('delayed Firebase keeps live pools and local interests, then reloads the remote catalog', () async {
    final previousUser = app_state.prismUser;
    app_state.prismUser = app_constants.createGuestPrismUser();
    final ready = Completer<bool>();
    FirebaseInit.setFuture(ready.future);
    final apps = MethodChannelFirebase.appInstances;
    addTearDown(() async {
      app_state.prismUser = previousUser;
      remoteConfig.interests = '';
      MethodChannelFirebase.appInstances = apps;
      if (!ready.isCompleted) ready.complete(true);
      await FirebaseInit.readyFuture;
    });
    MethodChannelFirebase.appInstances = {};
    final cachedSettings = SettingsLocalDataSource(InMemoryLocalStore());
    await cachedSettings.set(
      app_constants.personalizedInterestsLocalCacheKey,
      '[{"name":"Cached","query":"cached-landscapes","imageUrl":"https://example.com/cached.jpg",'
      '"sources":["wallhaven"]}]',
    );
    final repository = _repository(
      favourites: _CountingFavourites(),
      firestore: _OneWallFirestore(),
      settings: cachedSettings,
      wallhaven: _InterestWallhaven(),
    );

    final cachedInterests = await repository.fetch(_firstPage);

    expect(_itemIds(cachedInterests.data?.items ?? const <FeedItemEntity>[]), <String>[
      'cached-landscapes',
      'visible-doc',
      'wall-doc',
    ]);
    final defaults = await _repository(
      favourites: _CountingFavourites(),
      firestore: _OneWallFirestore(),
      settings: SettingsLocalDataSource(InMemoryLocalStore()),
    ).fetch(_firstPage);
    expect(_itemIds(defaults.data?.items ?? const <FeedItemEntity>[]), <String>['visible-doc', 'wall-doc']);

    MethodChannelFirebase.appInstances = apps;
    remoteConfig.interests =
        '[{"name":"Remote","query":"remote-space","imageUrl":"https://example.com/remote.jpg",'
        '"sources":["wallhaven"]}]';
    ready.complete(true);
    await FirebaseInit.readyFuture;

    final refreshed = await repository.fetch(_firstPage);

    expect(_itemIds(refreshed.data?.items ?? const <FeedItemEntity>[]), <String>[
      'remote-space',
      'visible-doc',
      'wall-doc',
    ]);
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

  test('external favourites seed taste for both providers and pexels feedback can be undone', () async {
    final previousUser = app_state.prismUser;
    addTearDown(() => app_state.prismUser = previousUser);
    final settings = SettingsLocalDataSource(InMemoryLocalStore());
    final signals = TasteSignalStore(settings);
    final favourites = _PendingFavourites();
    app_state.prismUser = _signedInUser();
    final repository = _repository(
      favourites: favourites,
      firestore: _OneWallFirestore(),
      settings: settings,
      tasteSignals: signals,
    );
    const wallhaven = WallhavenWallpaper(
      core: WallpaperCore(
        id: 'wh',
        source: WallpaperSource.wallhaven,
        fullUrl: 'https://example.com/wh.jpg',
        thumbnailUrl: '',
        category: 'Space',
      ),
    );
    const pexels = PexelsWallpaper(
      core: WallpaperCore(
        id: 'px',
        source: WallpaperSource.pexels,
        fullUrl: 'https://example.com/px.jpg',
        thumbnailUrl: '',
        category: 'Nature',
      ),
    );
    favourites.completer.complete(
      Result.success(<FavouriteWallEntity>[
        const WallhavenFavouriteWall(id: 'wh', wallpaper: wallhaven),
        const PexelsFavouriteWall(id: 'px', wallpaper: pexels),
      ]),
    );
    await repository.fetch(_firstPage);
    expect(signals.isSeeded, isTrue);
    expect(signals.read().map((signal) => signal.action), everyElement(TasteAction.favourite));
    expect(signals.read(), hasLength(2));
    expect(
      signals.read().map((signal) => signal.terms),
      unorderedEquals(<List<String>>[
        <String>['space'],
        <String>['nature'],
      ]),
    );
    const item = PexelsFeedItem(id: 'px', wallpaper: pexels);
    await repository.lessLikeThis(item);
    expect(signals.read().last.action, TasteAction.lessLikeThis);
    final impressions = FeedImpressionStore(settings);
    expect(impressions.recentShows(DateTime.now().toUtc())['https://example.com/px.jpg'], 99);
    await repository.undoLessLikeThis(item);
    expect(impressions.recentShows(DateTime.now().toUtc()), isEmpty);
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

  test('catalog persistence does not delay a successful personalized feed', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    app_state.prismUser = app_constants.createGuestPrismUser();
    final _SlowOfflineCatalog catalog = _SlowOfflineCatalog();
    final PersonalizedFeedRepository repository = _repository(
      favourites: _CountingFavourites(),
      firestore: _OneWallFirestore(),
      settings: settings,
      offlineCatalog: catalog,
    );

    final result = await repository.fetch(_firstPage).timeout(const Duration(seconds: 2));
    await catalog.started.future;

    expect(result.isSuccess, isTrue);
    expect(result.data!.items, isNotEmpty);
    expect(catalog.release.isCompleted, isFalse);
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

  test('all source failures return bundled starters instead of an empty feed', () async {
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

    expect(result.isSuccess, isTrue);
    expect(result.data!.items, isNotEmpty);
    expect(result.data!.items.every(BundledWallpapers.isStarter), isTrue);
  });

  for (final (String providers, WallhavenWallpaperRepository wallhaven, PexelsWallpaperRepository pexels)
      in <(String, WallhavenWallpaperRepository, PexelsWallpaperRepository)>[
        ('time out', _HangingWallhaven(), _HangingPexels()),
        ('return failures', _OfflineWallhaven(), _OfflinePexels()),
      ]) {
    test('a feed whose Firestore reads time out and whose providers $providers logs no error', () async {
      final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
      await settings.set('onboarding_v2_interests', 'Photography');
      app_state.prismUser = _signedInUser();
      InMemoryLogSink.instance.clear();
      final PersonalizedFeedRepository repository = _repository(
        firestore: _TimedOutFirestore(),
        wallhaven: wallhaven,
        pexels: pexels,
        favourites: _CountingFavourites(),
        settings: settings,
      );

      final result = await repository.fetch(_firstPage);

      expect(result.isSuccess, isTrue);
      expect(result.data!.items.every(BundledWallpapers.isStarter), isTrue);
      final List<AppLogRecord> feedLogs = InMemoryLogSink.instance.records
          .where((record) => record.message.startsWith('[PersonalizedFeed]'))
          .toList();
      expect(feedLogs.where((record) => record.level == AppLogLevel.error), isEmpty);
      expect(
        feedLogs.where((record) => record.level == AppLogLevel.warn && record.message.contains('every source')),
        hasLength(1),
      );
    });
  }

  test('every source failing for a reason other than the network is still reported as an error', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set('onboarding_v2_interests', 'Photography');
    app_state.prismUser = _signedInUser();
    InMemoryLogSink.instance.clear();
    final PersonalizedFeedRepository repository = _repository(
      firestore: _OfflineFirestore(),
      wallhaven: _OfflineWallhaven(),
      pexels: _OfflinePexels(),
      favourites: _CountingFavourites(),
      settings: settings,
    );

    final result = await repository.fetch(_firstPage);

    expect(result.isSuccess, isTrue);
    expect(
      InMemoryLogSink.instance.records.where(
        (record) => record.level == AppLogLevel.error && record.message == '[PersonalizedFeed] fetch failed',
      ),
      hasLength(1),
    );
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

  test('a random slice that returns walls is not queried a second time', () async {
    final _CountingWallsFirestore firestore = _CountingWallsFirestore();
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      firestore: firestore,
      cache: _MemoryFeedCache(),
      settings: SettingsLocalDataSource(InMemoryLocalStore()),
      favourites: _CountingFavourites(),
    );

    await repository.fetch(_firstPage);

    expect(firestore.sourceTags.where((tag) => tag == 'personalized.gems'), hasLength(1));
  });

  test('a random slice that returns nothing wraps around once', () async {
    final _RecordingFirestore firestore = _RecordingFirestore();
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      firestore: firestore,
      cache: _MemoryFeedCache(),
      settings: SettingsLocalDataSource(InMemoryLocalStore()),
      favourites: _CountingFavourites(),
    );

    await repository.fetch(_firstPage);

    expect(firestore.sourceTags.where((tag) => tag == 'personalized.gems'), hasLength(2));
  });

  test('the blocked-creators load overlaps the pools instead of adding to them', () async {
    final _EmptyBlocks blocks = _EmptyBlocks()
      ..loadDelay = const Duration(milliseconds: 500)
      ..loaded = <String>{};
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      firestore: _SlowWallsFirestore(),
      cache: _MemoryFeedCache(),
      settings: SettingsLocalDataSource(InMemoryLocalStore()),
      favourites: _CountingFavourites(),
      blocks: blocks,
    );

    final Stopwatch watch = Stopwatch()..start();
    final result = await repository.fetch(_firstPage);
    watch.stop();

    expect(result.data!.items, isNotEmpty);
    expect(watch.elapsedMilliseconds, lessThan(900));
  });

  test('creators from a slow blocked load are still filtered and never cached', () async {
    final _EmptyBlocks blocks = _EmptyBlocks()
      ..loadDelay = const Duration(milliseconds: 300)
      ..loaded = <String>{'creator-id'};
    final _MemoryFeedCache cache = _MemoryFeedCache();
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = _repository(
      firestore: _OneWallFirestore(),
      cache: cache,
      settings: SettingsLocalDataSource(InMemoryLocalStore()),
      favourites: _CountingFavourites(),
      blocks: blocks,
    );

    final result = await repository.fetch(_firstPage);

    expect(_itemIds(result.data!.items), isEmpty);
    expect((cache.snapshot!.payload! as Map)['items'], isEmpty);
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

  test('a later page serves unseen cached metadata before reporting offline exhaustion', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    final _OneWallFirestore firestore = _OneWallFirestore()..fail = true;
    final _ToggleWallhaven wallhaven = _ToggleWallhaven()..fail = true;
    final _TogglePexels pexels = _TogglePexels()..fail = true;
    final _MemoryFeedCache cache = _MemoryFeedCache()
      ..snapshot = FeedSnapshot(
        payload: <String, Object?>{
          'filters': '100.100',
          'items': <Map<String, Object?>>[
            encodeFeedItem(_prismItem('cached-1')),
            encodeFeedItem(_prismItem('cached-2')),
          ],
        },
        cachedAtUtc: DateTime.now().toUtc(),
        ttlHours: 2,
      );
    app_state.prismUser = _signedInUser();
    final PersonalizedFeedRepository repository = PersonalizedFeedRepositoryImpl(
      firestore,
      cache,
      settings,
      wallhaven,
      pexels,
      _EmptyBlocks(),
      _CountingFavourites(),
      TasteSignalStore(settings),
      FeedImpressionStore(settings),
    );

    final result = await repository.fetch(
      FetchPersonalizedFeedRequest(
        page: 2,
        refresh: false,
        seenKeys: <String>['prism:cached-1'],
        existingItems: <FeedItemEntity>[_prismItem('cached-1')],
      ),
    );

    expect(_itemIds(result.data?.items ?? const <FeedItemEntity>[]), <String>['cached-2']);
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

  test('refresh uses updated profile interests instead of an indefinitely cached profile', () async {
    app_state.prismUser = _signedInUser();
    final firestore = _StaleProfileFirestore();
    final wallhaven = _ToggleWallhaven();
    final repository = _repository(
      firestore: firestore,
      wallhaven: wallhaven,
      settings: SettingsLocalDataSource(InMemoryLocalStore()),
      favourites: _CountingFavourites(),
    );
    await repository.fetch(_firstPage);
    expect(wallhaven.queries, isNotEmpty);
    expect(wallhaven.queries, everyElement('nature'));
    wallhaven.queries.clear();
    firestore.interest = 'Space';

    await repository.fetch(_firstPage);

    expect(wallhaven.queries, isNotEmpty);
    expect(wallhaven.queries, everyElement('space'));
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

  test('following feed does not use the session email graph', () async {
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

    expect(firestore.sourceTags, isNot(contains('personalized.creator_chunk_1')));
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

  group('primeFirstPage', () {
    Future<
      ({
        PersonalizedFeedRepository repository,
        _GatedWallsFirestore firestore,
        SettingsLocalDataSource settings,
        _EmptyBlocks blocks,
        _MemoryFeedCache cache,
        TasteSignalStore signals,
        FeedImpressionStore impressions,
      })
    >
    build() async {
      final _GatedWallsFirestore firestore = _GatedWallsFirestore();
      final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
      final _EmptyBlocks blocks = _EmptyBlocks();
      final _MemoryFeedCache cache = _MemoryFeedCache();
      final signals = TasteSignalStore(settings);
      final impressions = FeedImpressionStore(settings);
      app_state.prismUser = _signedInUser();
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        cache: cache,
        settings: settings,
        favourites: _CountingFavourites(),
        blocks: blocks,
        tasteSignals: signals,
        impressions: impressions,
      );
      return (
        repository: repository,
        firestore: firestore,
        settings: settings,
        blocks: blocks,
        cache: cache,
        signals: signals,
        impressions: impressions,
      );
    }

    List<String> keys(PersonalizedFeedPage? page) => page!.items.map((item) => item.canonicalKey).toList();

    FeedSnapshot cacheSnapshot(List<FeedItemEntity> items) => FeedSnapshot(
      cachedAtUtc: DateTime.now().toUtc(),
      ttlHours: 2,
      payload: <String, Object?>{'filters': '100.100', 'items': items.map(encodeFeedItem).toList()},
    );

    int gems(_GatedWallsFirestore f) => f.sourceTags.where((tag) => tag == 'personalized.gems').length;

    test('a completed unknown-block prime is discarded and rebuilt once the list is known', () async {
      final _GatedWallsFirestore firestore = _GatedWallsFirestore()..gate.complete();
      final _BlocksLoadedLater blocks = _BlocksLoadedLater();
      app_state.prismUser = _signedInUser();
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: blocks,
      );

      final PersonalizedFeedPage? primed = await repository.primeFirstPage();
      expect(primed, isNotNull);
      expect(primed!.items, isEmpty);
      blocks.listLoaded = true;
      final PersonalizedFeedPage? rebuilt = await repository.primeFirstPage();
      final Result<PersonalizedFeedPage> fetched = await repository.fetch(_firstPage);

      expect(rebuilt, isNotNull);
      expect(rebuilt!.items.map((item) => item.id), unorderedEquals(<String>['visible-doc', 'wall-doc']));
      expect(fetched.isSuccess, isTrue);
      expect(fetched.data!.items.map((item) => item.id), unorderedEquals(<String>['visible-doc', 'wall-doc']));
      expect(gems(firestore), 2);
    });

    test('a direct refresh rebuilds when its captured unknown block list becomes known in flight', () async {
      final _GatedWallsFirestore firestore = _GatedWallsFirestore();
      final _BlocksLoadedLater blocks = _BlocksLoadedLater();
      app_state.prismUser = _signedInUser();
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: blocks,
      );

      final Future<Result<PersonalizedFeedPage>> fetching = repository.fetch(_firstPage);
      await Future<void>.delayed(Duration.zero);
      blocks.listLoaded = true;
      firestore.gate.complete();
      final Result<PersonalizedFeedPage> fetched = await fetching;

      expect(fetched.isSuccess, isTrue);
      expect(fetched.data!.items.map((item) => item.id), unorderedEquals(<String>['visible-doc', 'wall-doc']));
      expect(gems(firestore), 2);
    });

    test('the next page-one refresh takes the primed page and hits the sources once', () async {
      final env = await build();
      env.firestore.gate.complete();

      final PersonalizedFeedPage? primed = await env.repository.primeFirstPage();
      final result = await env.repository.fetch(_firstPage);

      expect(primed, isNotNull);
      expect(keys(result.data), keys(primed));
      expect(gems(env.firestore), 1);
    });

    test('a primed page is used once. The second fetch hits the sources again', () async {
      final env = await build();
      env.firestore.gate.complete();

      await env.repository.primeFirstPage();
      await env.repository.fetch(_firstPage);
      await env.repository.fetch(_firstPage);

      expect(gems(env.firestore), 2);
    });

    test('a mix change after the prime fetches again', () async {
      final env = await build();
      env.firestore.gate.complete();

      await env.repository.primeFirstPage();
      await env.settings.set(app_constants.personalizedFeedMixLocalKey, 'adventurous');
      await env.repository.fetch(_firstPage);

      expect(gems(env.firestore), 2);
    });

    for (final setting in <({String key, int value})>[
      (key: 'WHcategories', value: 110),
      (key: 'WHpurity', value: 110),
    ]) {
      test('a ${setting.key} content filter change after the prime fetches again', () async {
        final env = await build();
        env.firestore.gate.complete();
        await env.repository.primeFirstPage();
        await env.settings.set(setting.key, setting.value);

        expect((await env.repository.fetch(_firstPage)).isSuccess, isTrue);
        expect(gems(env.firestore), 2);
      });
    }

    test('an interest change after the prime fetches again', () async {
      final env = await build();
      env.firestore.gate.complete();

      await env.repository.primeFirstPage();
      await env.settings.set(OnboardingV2Keys.selectedInterests, 'Nature,Space');
      await env.repository.fetch(_firstPage);

      expect(gems(env.firestore), 2);
    });

    test('a retake refresh invalidates the older in-flight prime', () async {
      final env = await build();

      final Future<PersonalizedFeedPage?> oldPrime = env.repository.primeFirstPage();
      await Future<void>.delayed(Duration.zero);
      await env.settings.set(OnboardingV2Keys.selectedInterests, 'Nature,Space');
      final Future<Result<PersonalizedFeedPage>> refreshed = env.repository.fetch(_firstPage);
      await Future<void>.delayed(Duration.zero);
      env.firestore.gate.complete();

      final PersonalizedFeedPage? oldPage = await oldPrime;
      final Result<PersonalizedFeedPage> newPage = await refreshed;

      expect(oldPage, isNull);
      expect(newPage.isSuccess, isTrue);
      expect(gems(env.firestore), 2);
    });

    test('an old refresh retry cannot replace a newer retake prime', () async {
      final env = await build();

      final Future<Result<PersonalizedFeedPage>> oldFetch = env.repository.fetch(_firstPage);
      await Future<void>.delayed(Duration.zero);
      await env.settings.set(OnboardingV2Keys.selectedInterests, 'Nature,Space');
      final Future<PersonalizedFeedPage?> newPrime = env.repository.primeFirstPage();
      await Future<void>.delayed(Duration.zero);
      env.firestore.gate.complete();

      final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[oldFetch, newPrime]);

      expect(results[0], isA<Result<PersonalizedFeedPage>>());
      expect(results[1], isA<PersonalizedFeedPage>());
      expect(gems(env.firestore), 2);
    });

    test('a taste signal recorded after the prime fetches again', () async {
      final env = await build();
      env.firestore.gate.complete();

      await env.repository.primeFirstPage();
      await env.settings.set(
        'personalized_taste_signals_v1',
        '[{"a":"favourite","t":"2026-10-28T00:00:00.000Z","k":["nature"]}]',
      );
      await env.repository.fetch(_firstPage);

      expect(gems(env.firestore), 2);
    });

    test('an impression recorded after the prime fetches again', () async {
      final env = await build();
      env.firestore.gate.complete();
      final FeedImpressionStore impressions = FeedImpressionStore(env.settings);

      await env.repository.primeFirstPage();
      await impressions.hide('https://example.com/hidden.jpg', DateTime.now().toUtc());
      await env.repository.fetch(_firstPage);

      expect(gems(env.firestore), 2);
    });

    for (final String change in <String>['taste signal', 'impression']) {
      test('a $change recorded while a prime loads invalidates that prime', () async {
        final env = await build();
        final pending = env.repository.primeFirstPage();
        await Future<void>.delayed(Duration.zero);
        if (change == 'taste signal') {
          await TasteSignalStore(
            env.settings,
          ).record(TasteSignal(action: TasteAction.open, at: DateTime.now().toUtc(), terms: const <String>['nature']));
        } else {
          await FeedImpressionStore(env.settings).recordShown(<String>['seen-wall'], DateTime.now().toUtc());
        }
        env.firestore.gate.complete();

        expect(await pending, isNull);
        expect((await env.repository.fetch(_firstPage)).isSuccess, isTrue);
        expect(gems(env.firestore), 2);
      });
    }

    test('a session cycle with cleared history cannot revive an older prime', () async {
      final env = await build();
      final pending = env.repository.primeFirstPage();
      await Future<void>.delayed(Duration.zero);
      app_state.prismUser = app_constants.createGuestPrismUser();
      await env.signals.clear(allowReseed: true);
      await env.impressions.clear();
      app_state.prismUser = _signedInUser();
      env.firestore.gate.complete();

      expect(await pending, isNull);
      expect((await env.repository.fetch(_firstPage)).isSuccess, isTrue);
      expect(gems(env.firestore), 2);
    });

    test('the prime is usable before fifteen minutes and expires at the boundary', () {
      fakeAsync((async) {
        final clock = async.getClock(DateTime.utc(2026, 10, 28));
        final firestore = _CountingWallsFirestore();
        final repository = _repository(
          firestore: firestore,
          settings: SettingsLocalDataSource(InMemoryLocalStore()),
          favourites: _CountingFavourites(),
          offlineCatalog: _RecordingOfflineCatalog(),
          now: clock.now,
        );
        PersonalizedFeedPage? primed;
        repository.primeFirstPage().then((page) => primed = page);
        async.flushMicrotasks();
        expect(primed, isNotNull);

        async.elapse(const Duration(minutes: 14, seconds: 59));
        PersonalizedFeedPage? cached;
        repository.readCached().then((page) => cached = page);
        async.flushMicrotasks();
        expect(keys(cached), keys(primed));
        expect(firestore.sourceTags.where((tag) => tag == 'personalized.gems'), hasLength(1));

        async.elapse(const Duration(seconds: 1));
        Result<PersonalizedFeedPage>? result;
        repository.fetch(_firstPage).then((page) => result = page);
        async.flushMicrotasks();
        expect(result?.isSuccess, isTrue);
        expect(firestore.sourceTags.where((tag) => tag == 'personalized.gems'), hasLength(2));
      });
    });

    test('an expired in-flight prime cannot hold a new consumer behind its cache write', () {
      fakeAsync((async) {
        final clock = async.getClock(DateTime.utc(2026, 10, 28));
        final firestore = _CountingWallsFirestore();
        final cache = _WriteGatedFeedCache();
        final repository = _repository(
          firestore: firestore,
          cache: cache,
          settings: SettingsLocalDataSource(InMemoryLocalStore()),
          favourites: _CountingFavourites(),
          offlineCatalog: _RecordingOfflineCatalog(),
          now: clock.now,
        );
        PersonalizedFeedPage? primed;
        repository.primeFirstPage().then((page) => primed = page);
        async.flushMicrotasks();
        expect(cache.started.isCompleted, isTrue);
        async.elapse(const Duration(minutes: 15));

        Result<PersonalizedFeedPage>? result;
        repository.fetch(_firstPage).then((page) => result = page);
        async.flushMicrotasks();
        expect(result?.isSuccess, isTrue);
        expect(firestore.sourceTags.where((tag) => tag == 'personalized.gems'), hasLength(2));
        cache.release.complete();
        async.flushMicrotasks();
        expect(primed, isNull);
      });
    });

    test('an account change after the prime fetches again', () async {
      final env = await build();
      env.firestore.gate.complete();

      await env.repository.primeFirstPage();
      app_state.prismUser = app_constants.createGuestPrismUser();
      await env.repository.fetch(_firstPage);

      expect(gems(env.firestore), 2);
    });

    test('concurrent primes share the same load', () async {
      final env = await build();

      final Future<PersonalizedFeedPage?> first = env.repository.primeFirstPage();
      final Future<PersonalizedFeedPage?> second = env.repository.primeFirstPage();
      await Future<void>.delayed(Duration.zero);
      env.firestore.gate.complete();

      final List<PersonalizedFeedPage?> pages = await Future.wait(<Future<PersonalizedFeedPage?>>[first, second]);

      expect(pages, everyElement(isNotNull));
      expect(gems(env.firestore), 1);
    });

    test('favourite seeding becomes part of the completed prime identity', () async {
      final _GatedWallsFirestore firestore = _GatedWallsFirestore();
      final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
      final _CountingFavourites favourites = _SeededFavourites();
      app_state.prismUser = _signedInUser();
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        cache: _MemoryFeedCache(),
        settings: settings,
        favourites: favourites,
      );
      firestore.gate.complete();

      final PersonalizedFeedPage? page = await repository.primeFirstPage();
      final Result<PersonalizedFeedPage> fetched = await repository.fetch(_firstPage);

      expect(page, isNotNull);
      expect(fetched.isSuccess, isTrue);
      expect(firestore.sourceTags.where((tag) => tag == 'personalized.gems'), hasLength(1));
    });

    test('concurrent refreshes share the same in-flight prime', () async {
      final env = await build();

      final Future<PersonalizedFeedPage?> prime = env.repository.primeFirstPage();
      final Future<Result<PersonalizedFeedPage>> first = env.repository.fetch(_firstPage);
      final Future<Result<PersonalizedFeedPage>> second = env.repository.fetch(_firstPage);
      await Future<void>.delayed(Duration.zero);
      env.firestore.gate.complete();

      await Future.wait<Object?>(<Future<Object?>>[prime, first, second]);

      expect(gems(env.firestore), 1);
    });

    for (final bool offerPrime in <bool>[false, true]) {
      test('concurrent refreshes share one recovery with offerPrime=$offerPrime', () async {
        final _GatedWallsFirestore firestore = _GatedWallsFirestore();
        final _BlocksLoadedLater blocks = _BlocksLoadedLater();
        app_state.prismUser = _signedInUser();
        final PersonalizedFeedRepository repository = _repository(
          firestore: firestore,
          settings: SettingsLocalDataSource(InMemoryLocalStore()),
          favourites: _CountingFavourites(),
          blocks: blocks,
        );

        final Future<PersonalizedFeedPage?>? prime = offerPrime ? repository.primeFirstPage() : null;
        final Future<Result<PersonalizedFeedPage>> first = repository.fetch(_firstPage);
        final Future<Result<PersonalizedFeedPage>> second = repository.fetch(_firstPage);
        await Future<void>.delayed(Duration.zero);
        blocks.listLoaded = true;
        firestore.gate.complete();
        final List<Result<PersonalizedFeedPage>> results = await Future.wait<Result<PersonalizedFeedPage>>(
          <Future<Result<PersonalizedFeedPage>>>[first, second],
        );

        if (prime != null) expect(await prime, isNull);
        for (final Result<PersonalizedFeedPage> result in results) {
          expect(result.isSuccess, isTrue);
          expect(result.data!.items.map((item) => item.id), unorderedEquals(<String>['visible-doc', 'wall-doc']));
        }
        expect(gems(firestore), 2);

        final Result<PersonalizedFeedPage> next = await repository.fetch(_firstPage);

        expect(next.isSuccess, isTrue);
        expect(next.data!.items.map((item) => item.id), unorderedEquals(<String>['visible-doc', 'wall-doc']));
        expect(gems(firestore), 3);
      });
    }

    test('a generation change supersedes an in-flight unknown-block prime recovery', () async {
      final _GatedWallsFirestore firestore = _GatedWallsFirestore();
      final _BlocksLoadedLater blocks = _BlocksLoadedLater();
      final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
      app_state.prismUser = _signedInUser();
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: settings,
        favourites: _CountingFavourites(),
        blocks: blocks,
      );

      final Future<PersonalizedFeedPage?> oldPrime = repository.primeFirstPage();
      await Future<void>.delayed(Duration.zero);
      blocks.listLoaded = true;
      await settings.set(app_constants.personalizedFeedMixLocalKey, 'adventurous');
      final Future<PersonalizedFeedPage?> newPrime = repository.primeFirstPage();
      firestore.gate.complete();
      final List<PersonalizedFeedPage?> pages = await Future.wait(<Future<PersonalizedFeedPage?>>[oldPrime, newPrime]);
      final Result<PersonalizedFeedPage> fetched = await repository.fetch(_firstPage);

      expect(pages.first, isNull);
      expect(pages.last, isNotNull);
      expect(fetched.isSuccess, isTrue);
      expect(fetched.data!.items.map((item) => item.id), unorderedEquals(<String>['visible-doc', 'wall-doc']));
      expect(gems(firestore), 2);
    });

    test('a newly blocked creator is removed from the primed page at delivery', () async {
      final env = await build();
      env.firestore.gate.complete();

      await env.repository.primeFirstPage();
      env.blocks.cached = <String>{'creator-id'};
      final Result<PersonalizedFeedPage> result = await env.repository.fetch(_firstPage);

      expect(result.data!.items, isEmpty);
      expect(gems(env.firestore), 1);
    });

    test('page two reloads follows after taking a primed first page', () async {
      final env = await build();
      env.firestore.gate.complete();

      await env.repository.primeFirstPage();
      await env.repository.fetch(_firstPage);
      await env.repository.fetch(
        const FetchPersonalizedFeedRequest(
          page: 2,
          refresh: false,
          seenKeys: <String>[],
          existingItems: <FeedItemEntity>[],
        ),
      );

      expect(env.firestore.sourceTags.where((tag) => tag == 'personalized.following_uids'), hasLength(2));
    });

    test('page two reloads follows when an invalidated handoff takes the newer prime', () async {
      final firestore = _PendingFreshFirestore();
      final settings = SettingsLocalDataSource(InMemoryLocalStore());
      app_state.prismUser = _signedInUser();
      final repository = _repository(firestore: firestore, settings: settings, favourites: _CountingFavourites());
      final oldPrime = repository.primeFirstPage();
      await firestore.freshStarted.future;
      await Future<void>.delayed(Duration.zero);
      final oldFetch = repository.fetch(_firstPage);
      await settings.set(app_constants.personalizedFeedMixLocalKey, 'adventurous');
      expect(await repository.primeFirstPage(), isNotNull);
      firestore.ready.complete();
      expect(await oldPrime, isNull);
      expect((await oldFetch).isSuccess, isTrue);
      await repository.fetch(
        const FetchPersonalizedFeedRequest(
          page: 2,
          refresh: false,
          seenKeys: <String>[],
          existingItems: <FeedItemEntity>[],
        ),
      );

      expect(firestore.sourceTags.where((tag) => tag == 'personalized.following_uids'), hasLength(3));
    });

    test('readCached returns a matching primed page without consuming it', () async {
      final env = await build();
      env.cache.snapshot = cacheSnapshot(<FeedItemEntity>[_prismItem('disk-old')]);
      env.repository.warmCache();
      await Future<void>.delayed(Duration.zero);
      env.firestore.gate.complete();

      final PersonalizedFeedPage? primed = await env.repository.primeFirstPage();
      final PersonalizedFeedPage? cached = await env.repository.readCached();
      final Result<PersonalizedFeedPage> fetched = await env.repository.fetch(_firstPage);

      expect(keys(cached), keys(primed));
      expect(keys(fetched.data), keys(primed));
      expect(keys(cached), isNot(contains('https://example.com/disk-old.jpg')));
      expect(gems(env.firestore), 1);
    });

    test('a prime joins a page-one refresh that started first', () async {
      final env = await build();

      final Future<Result<PersonalizedFeedPage>> fetch = env.repository.fetch(_firstPage);
      await Future<void>.delayed(Duration.zero);
      final Future<PersonalizedFeedPage?> prime = env.repository.primeFirstPage();
      await Future<void>.delayed(Duration.zero);
      env.firestore.gate.complete();

      final Result<PersonalizedFeedPage> fetched = await fetch;
      final PersonalizedFeedPage? primed = await prime;

      expect(keys(fetched.data), keys(primed));
      expect(gems(env.firestore), 1);
      await env.repository.fetch(_firstPage);

      expect(gems(env.firestore), 2);
    });

    test('a fetch that starts while the prime loads joins it', () async {
      final env = await build();

      final Future<PersonalizedFeedPage?> prime = env.repository.primeFirstPage();
      final Future<Result<PersonalizedFeedPage>> fetch = env.repository.fetch(_firstPage);
      await Future<void>.delayed(Duration.zero);
      env.firestore.gate.complete();

      final PersonalizedFeedPage? primed = await prime;
      final Result<PersonalizedFeedPage> result = await fetch;

      expect(keys(result.data), keys(primed));
      expect(gems(env.firestore), 1);
    });

    test('a failed prime handoff falls back to a fresh fetch', () async {
      final env = await build();
      env.firestore.gate.complete();

      expect(await env.repository.primeFirstPage(), isNotNull);
      env.blocks.failCachedRead = true;
      final Result<PersonalizedFeedPage> result = await env.repository.fetch(_firstPage);

      expect(result.isSuccess, isTrue);
      expect(gems(env.firestore), 2);
    });

    test('a rejected source and cache future does not poison the next prime handoff', () async {
      final firestore = _CountingWallsFirestore()..fail = true;
      final cache = _RecoveringFeedCache();
      final settings = SettingsLocalDataSource(InMemoryLocalStore());
      final repository = _repository(
        firestore: firestore,
        cache: cache,
        settings: settings,
        favourites: _CountingFavourites(),
        wallhaven: _OfflineWallhaven(),
        pexels: _OfflinePexels(),
      );

      expect(await repository.primeFirstPage(), isNull);
      firestore.fail = false;
      cache.failRead = false;
      final result = await repository.fetch(_firstPage);

      expect(result.isSuccess, isTrue);
      expect(result.data!.items, isNotEmpty);
      expect(firestore.sourceTags.where((tag) => tag == 'personalized.gems'), hasLength(2));
    });

    test('readCached paints the disk page instead of waiting for a prime still in flight', () async {
      final cache = _WriteGatedFeedCache()..snapshot = cacheSnapshot(<FeedItemEntity>[_prismItem('disk-old')]);
      final repository = _repository(
        firestore: _CountingWallsFirestore(),
        cache: cache,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );
      final Future<PersonalizedFeedPage?> prime = repository.primeFirstPage();
      await cache.started.future;

      final PersonalizedFeedPage? page = await repository.readCached().timeout(const Duration(seconds: 1));

      expect(page!.items.map((item) => item.id), <String>['disk-old']);
      cache.release.complete();
      await prime;
    });

    test('a late cache read cannot return a prime from a different session', () async {
      final firestore = _CountingWallsFirestore();
      final cache = _DelayedFeedCache()..snapshot = cacheSnapshot(<FeedItemEntity>[_prismItem('old-cache')]);
      final repository = _repository(
        firestore: firestore,
        cache: cache,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );
      app_state.prismUser = _signedInUser();
      final pending = repository.readCached();
      await Future<void>.delayed(Duration.zero);
      app_state.prismUser = app_constants.createGuestPrismUser();
      expect(await repository.primeFirstPage(), isNotNull);
      cache.release.complete();

      expect(await pending, isNull);
    });

    for (final String change in <String>['account', 'clear', 'mix']) {
      test('$change change during the cache write prevents stale catalog side effects', () async {
        final settings = SettingsLocalDataSource(InMemoryLocalStore());
        final signals = TasteSignalStore(settings);
        final impressions = FeedImpressionStore(settings);
        final cache = _WriteGatedFeedCache();
        final catalog = _RecordingOfflineCatalog();
        app_state.prismUser = _signedInUser();
        final repository = _repository(
          firestore: _CountingWallsFirestore(),
          cache: cache,
          settings: settings,
          favourites: _CountingFavourites(),
          tasteSignals: signals,
          impressions: impressions,
          offlineCatalog: catalog,
        );
        final pending = repository.primeFirstPage();
        await cache.started.future;
        switch (change) {
          case 'account':
            app_state.prismUser = app_constants.createGuestPrismUser();
          case 'clear':
            await signals.clear();
            await impressions.clear();
          case 'mix':
            await settings.set(app_constants.personalizedFeedMixLocalKey, 'adventurous');
        }
        cache.release.complete();

        expect(await pending, isNull);
        expect(catalog.remembered, isEmpty);
      });
    }
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

    test('returns bundled starters when nothing is cached', () async {
      final PersonalizedFeedRepository repository = _repository(
        firestore: _EmptyFirestore(),
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );

      final PersonalizedFeedPage? page = await repository.readCached();

      expect(page, isNotNull);
      expect(page!.items, isNotEmpty);
      expect(page.items.every(BundledWallpapers.isStarter), isTrue);
      expect(page.hasMore, isFalse);
    });

    test('warmCache reads the disk once and readCached takes that page', () async {
      app_state.prismUser = _signedInUser();
      final _CountingFeedCache cache = _CountingFeedCache()..snapshot = snapshot(<FeedItemEntity>[_prismItem('a')]);
      final PersonalizedFeedRepository repository = _repository(
        firestore: _EmptyFirestore(),
        cache: cache,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );

      repository.warmCache();
      repository.warmCache();
      final PersonalizedFeedPage? warmed = await repository.readCached();

      expect(cache.scopes, <String>['feed-test-user']);
      expect(_itemIds(warmed!.items), <String>['a']);

      await repository.readCached();
      expect(cache.scopes, <String>['feed-test-user', 'feed-test-user']);
    });

    test('a failed warm read is handled before a screen consumes it', () async {
      final repository = _repository(
        firestore: _EmptyFirestore(),
        cache: _FailingFeedCache(),
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );
      repository.warmCache();
      await Future<void>.delayed(Duration.zero);

      await expectLater(repository.readCached(), throwsStateError);
    });

    test('a creator blocked after warmCache started is not in the page readCached returns', () async {
      app_state.prismUser = _signedInUser();
      final _CountingFeedCache cache = _CountingFeedCache()
        ..snapshot = snapshot(<FeedItemEntity>[_prismItem('a', authorUid: 'blocked-uid'), _prismItem('b')]);
      final _EmptyBlocks blocks = _EmptyBlocks();
      final PersonalizedFeedRepository repository = _repository(
        firestore: _EmptyFirestore(),
        cache: cache,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: blocks,
      );

      repository.warmCache();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      blocks.cached = <String>{'blocked-uid'};
      final PersonalizedFeedPage? page = await repository.readCached();

      expect(_itemIds(page!.items), <String>['b']);
    });

    test('readCached reads fresh when the user changed after warmCache', () async {
      app_state.prismUser = _signedInUser();
      final _CountingFeedCache cache = _CountingFeedCache()..snapshot = snapshot(<FeedItemEntity>[_prismItem('a')]);
      final PersonalizedFeedRepository repository = _repository(
        firestore: _EmptyFirestore(),
        cache: cache,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );

      repository.warmCache();
      app_state.prismUser = app_constants.createGuestPrismUser();
      await repository.readCached();

      expect(cache.scopes, <String>['feed-test-user', 'guest']);
    });

    test('a warm page cannot restore a wallpaper hidden since warming', () async {
      final settings = SettingsLocalDataSource(InMemoryLocalStore());
      final impressions = FeedImpressionStore(settings);
      final item = _prismItem('hidden');
      final repository = _repository(
        firestore: _EmptyFirestore(),
        cache: _MemoryFeedCache()..snapshot = snapshot(<FeedItemEntity>[item, _prismItem('keep')]),
        settings: settings,
        impressions: impressions,
        favourites: _CountingFavourites(),
      );
      repository.warmCache();
      await Future<void>.delayed(Duration.zero);
      await impressions.hide(item.canonicalKey, DateTime.now().toUtc());

      expect(_itemIds((await repository.readCached())!.items), <String>['keep']);
    });

    test('a warm page waits for initial blocks before exposing cached creators', () async {
      final blocks = _PendingBlocks();
      final repository = _repository(
        firestore: _EmptyFirestore(),
        cache: _MemoryFeedCache()
          ..snapshot = snapshot(<FeedItemEntity>[_prismItem('blocked', authorUid: 'blocked-uid')]),
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: blocks,
      );
      repository.warmCache();
      bool returned = false;
      final pending = repository.readCached().then((page) {
        returned = true;
        return page;
      });
      await Future<void>.delayed(Duration.zero);
      expect(returned, isFalse);
      blocks.initial.complete(KnownBlockedCreators(<String>{'blocked-uid'}));

      final page = await pending;
      expect(page!.items.any((item) => item.id == 'blocked'), isFalse);
    });

    test('a warm page observes content filters changed since warming', () async {
      final settings = SettingsLocalDataSource(InMemoryLocalStore());
      final repository = _repository(
        firestore: _EmptyFirestore(),
        cache: _MemoryFeedCache()
          ..snapshot = snapshot(<FeedItemEntity>[_prismItem('prism'), _wallhavenItem('wh')], filters: '100.100'),
        settings: settings,
        favourites: _CountingFavourites(),
      );
      repository.warmCache();
      await Future<void>.delayed(Duration.zero);
      await settings.set('WHpurity', 110);

      expect(_itemIds((await repository.readCached())!.items), <String>['prism']);
    });

    test('a warm page is discarded if the account changes while readCached waits', () async {
      app_state.prismUser = _signedInUser();
      final cache = _DelayedFeedCache()..snapshot = snapshot(<FeedItemEntity>[_prismItem('previous-user')]);
      final repository = _repository(
        firestore: _EmptyFirestore(),
        cache: cache,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );
      repository.warmCache();
      final pending = repository.readCached();
      app_state.prismUser = app_constants.createGuestPrismUser();
      cache.release.complete();

      expect(await pending, isNull);
    });

    test('serves bundled starters when every remote feed source is offline', () async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      final PersonalizedFeedRepository repository = PersonalizedFeedRepositoryImpl(
        _OfflineFirestore(),
        _EmptyFeedCache(),
        SettingsLocalDataSource(InMemoryLocalStore()),
        _ToggleWallhaven()..fail = true,
        _TogglePexels()..fail = true,
        _EmptyBlocks(),
        _CountingFavourites(),
        TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())),
        FeedImpressionStore(SettingsLocalDataSource(InMemoryLocalStore())),
      );

      final result = await repository.fetch(_firstPage);

      expect(result.isSuccess, isTrue);
      expect(result.data!.items, isNotEmpty);
      expect(result.data!.items.every(BundledWallpapers.isStarter), isTrue);
    });

    test('remote feed results replace bundled starters in the returned feed and cache', () async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      final _MemoryFeedCache cache = _MemoryFeedCache();
      final PersonalizedFeedRepository repository = _repository(
        firestore: _OneWallFirestore(),
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        cache: cache,
      );

      final result = await repository.fetch(_firstPage);

      expect(result.isSuccess, isTrue);
      expect(result.data!.items, isNotEmpty);
      expect(result.data!.items.any(BundledWallpapers.isStarter), isFalse);
      final Object? payload = cache.snapshot?.payload;
      final Object? cachedItems = payload is Map ? payload['items'] : null;
      expect(cachedItems, isA<List>());
      expect(
        (cachedItems! as List)
            .map((encoded) => decodeFeedItem(encoded as Map<String, dynamic>))
            .whereType<FeedItemEntity>()
            .any(BundledWallpapers.isStarter),
        isFalse,
      );
    });

    test('returns at most 24 items with their keys after the block list loads', () async {
      app_state.prismUser = _signedInUser();
      final _EmptyBlocks blocks = _EmptyBlocks();
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
            _prismItem('keep', authorUid: 'kept-uid'),
            _prismItem('drop', authorUid: 'blocked-uid'),
          ]),
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: _EmptyBlocks()..cached = <String>{'blocked-uid'},
      );

      expect(_itemIds((await repository.readCached())!.items), <String>['keep']);
    });

    test('an unknown block list drops cached Prism creators and keeps cached Wallhaven items', () async {
      app_state.prismUser = _signedInUser();
      final PersonalizedFeedRepository repository = _repository(
        firestore: _EmptyFirestore(),
        cache: _MemoryFeedCache()
          ..snapshot = snapshot(<FeedItemEntity>[_prismItem('drop', authorUid: 'blocked-uid'), _wallhavenItem('wh')]),
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: _UnknownBlocks(),
      );

      expect(_itemIds((await repository.readCached())!.items), <String>['wh']);
    });

    test('an unknown block list does not overwrite the saved mixed feed', () async {
      app_state.prismUser = _signedInUser();
      final _MemoryFeedCache cache = _MemoryFeedCache()
        ..snapshot = snapshot(<FeedItemEntity>[_prismItem('prism'), _wallhavenItem('wallhaven')]);
      final PersonalizedFeedRepository repository = _repository(
        firestore: _EmptyFirestore(),
        cache: cache,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: _UnknownBlocks(),
      );
      final Object? originalItems = (cache.snapshot!.payload! as Map)['items'];

      await repository.fetch(_firstPage);

      expect(identical((cache.snapshot!.payload! as Map)['items'], originalItems), isTrue);
      expect((cache.snapshot!.payload! as Map)['items'], hasLength(2));
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
      await impressions.hide(hidden.canonicalKey, DateTime.now().toUtc());
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

    test('drops anime Prism walls while the anime setting is off', () async {
      final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
      app_state.prismUser = _signedInUser();
      final PersonalizedFeedRepository repository = _repository(
        firestore: _EmptyFirestore(),
        cache: _MemoryFeedCache()
          ..snapshot = snapshot(<FeedItemEntity>[
            _prismItem('anime', tags: <String>['Anime']),
            _prismItem('other'),
          ]),
        settings: settings,
        favourites: _CountingFavourites(),
      );
      expect(_itemIds((await repository.readCached())!.items), <String>['other']);

      await settings.set('WHcategories', 110);

      expect(_itemIds((await repository.readCached())!.items), <String>['anime', 'other']);
    });

    test('drops AI Prism walls while the AI setting is off', () async {
      final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
      app_state.prismUser = _signedInUser();
      final PersonalizedFeedRepository repository = _repository(
        firestore: _EmptyFirestore(),
        cache: _MemoryFeedCache()
          ..snapshot = snapshot(<FeedItemEntity>[_prismItem('ai', ai: true), _prismItem('other')]),
        settings: settings,
        favourites: _CountingFavourites(),
      );
      expect(_itemIds((await repository.readCached())!.items), <String>['ai', 'other']);

      await AiContentFilter.setShowsAi(settings, false);

      expect(_itemIds((await repository.readCached())!.items), <String>['other']);
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

  test('the feed leaves out anime Prism walls while the anime setting is off', () async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    PersonalizedFeedRepository repository() => _repository(
      firestore: _AnimeWallFirestore(),
      settings: settings,
      favourites: _CountingFavourites(),
      impressions: FeedImpressionStore(SettingsLocalDataSource(InMemoryLocalStore())),
    );

    final hidden = await repository().fetch(_firstPage);
    expect(_itemIds(hidden.data!.items), <String>['visible-doc']);

    await settings.set('WHcategories', 110);
    final shown = await repository().fetch(_firstPage);
    expect(_itemIds(shown.data!.items), <String>['anime-doc', 'visible-doc']);
  });

  test('the feed leaves out AI Prism walls while the AI setting is off', () async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    PersonalizedFeedRepository repository() => _repository(
      firestore: _AiWallFirestore(),
      settings: settings,
      favourites: _CountingFavourites(),
      impressions: FeedImpressionStore(SettingsLocalDataSource(InMemoryLocalStore())),
    );

    final shown = await repository().fetch(_firstPage);
    expect(_itemIds(shown.data!.items), <String>['ai-doc', 'visible-doc']);

    await AiContentFilter.setShowsAi(settings, false);
    final hidden = await repository().fetch(_firstPage);
    expect(_itemIds(hidden.data!.items), <String>['visible-doc']);
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
    test('an unknown block list fails the page, and the retry queries from the first creator page', () async {
      app_state.prismUser = _signedInUser();
      final firestore = _FollowingGraphFirestore();
      final blocks = _BlocksLoadedLater();
      final repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: blocks,
      );

      final failed = await repository.fetchFollowing(page: 1);

      expect(failed.isFailure, isTrue);
      expect(failed.data, isNull);
      blocks.listLoaded = true;

      final retry = await repository.fetchFollowing(page: 1);

      expect(retry.data!.items.map((item) => item.id), <String>['wall-for-creator-uid']);
      final wallQueries = firestore.specs.where((spec) => spec.collection == 'walls').toList();
      expect(wallQueries, hasLength(2));
      expect(wallQueries.every((spec) => spec.startAfterDocId == null), isTrue);
    });

    test('reads UID relation edges and queries walls by creatorUid, ignoring session email follows', () async {
      app_state.prismUser = _signedInUser(following: const <String>['private@example.test']);
      final firestore = _FollowingGraphFirestore();
      final repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );

      final result = await repository.fetchFollowing(page: 1);

      expect(result.data!.items, hasLength(1));
      expect(firestore.specs.first.collection, 'profiles/feed-test-user/following');
      final wallQuery = firestore.specs.last;
      expect(wallQuery.collection, 'walls');
      expect(wallQuery.filters.map((filter) => filter.field), contains('creatorUid'));
      expect(wallQuery.filters.map((filter) => filter.field), isNot(contains('email')));
      expect(wallQuery.filters.last.value, <String>['creator-uid']);
    });

    test('refresh reads follow and unfollow changes from the UID graph, not session email follows', () async {
      app_state.prismUser = _signedInUser(following: const <String>['stale-session@example.test']);
      final firestore = _FollowingGraphFirestore();
      final repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );

      expect((await repository.fetchFollowing(page: 1)).data!.items.single.id, 'wall-for-creator-uid');
      firestore.followedUid = 'new-creator-uid';
      expect((await repository.fetchFollowing(page: 1)).data!.items.single.id, 'wall-for-new-creator-uid');
      firestore.followedUid = null;
      expect((await repository.fetchFollowing(page: 1)).data!.items, isEmpty);
      expect(firestore.followGraphReads, 3);
      expect(
        firestore.specs
            .where((spec) => spec.collection == 'walls')
            .every((spec) => spec.filters.every((filter) => filter.field != 'email')),
        isTrue,
      );
    });

    test('equal timestamps use document identity as a stable global tie breaker', () async {
      app_state.prismUser = _signedInUser(
        following: List<String>.generate(11, (i) => 'c${i.toString().padLeft(2, '0')}'),
      );
      final repository = _repository(
        firestore: _ChunkedFollowingFirestore(sameDate: true),
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );
      final ids = <String>[];
      for (int page = 1; page <= 10; page++) {
        final result = (await repository.fetchFollowing(page: page)).data!;
        ids.addAll(result.items.map((item) => item.id));
        if (!result.hasMore) break;
      }
      expect(ids, List<String>.generate(62, (i) => 'W${61 - i}'));
    });
    test('uneven creator chunks merge globally ordered bounded pages without losing buffered rows', () async {
      final uids = List<String>.generate(11, (i) => 'c${i.toString().padLeft(2, '0')}');
      app_state.prismUser = _signedInUser(following: uids);
      final firestore = _ChunkedFollowingFirestore();
      final repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );
      final ids = <String>[];
      for (int page = 1; page <= 10; page++) {
        final calls = firestore.specs.where((spec) => spec.collection == 'walls').length;
        final result = (await repository.fetchFollowing(page: page)).data!;
        expect(result.items.length, lessThanOrEqualTo(12));
        expect(firestore.specs.where((spec) => spec.collection == 'walls').length - calls, lessThanOrEqualTo(3));
        ids.addAll(result.items.map((item) => item.id));
        if (!result.hasMore) break;
      }
      expect(ids, List<String>.generate(62, (i) => 'W$i'));
      final wallSpecs = firestore.specs.where((spec) => spec.collection == 'walls').toList();
      expect(wallSpecs.every((spec) => spec.limit == 12), isTrue);
      expect(wallSpecs.skip(2).every((spec) => spec.startAfterDocId != null), isTrue);
      expect(wallSpecs.every((spec) => spec.orderBy.last.field == firestoreDocumentIdField), isTrue);
    });

    test('a late first Following page cannot replace refreshed chunk cursors', () async {
      app_state.prismUser = _signedInUser(following: const <String>['a-uid']);
      final firestore = _DelayedFollowingFirestore(rows: 57);
      final repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );
      final old = repository.fetchFollowing(page: 1);
      await firestore.started.future;
      await repository.fetchFollowing(page: 1);
      await repository.fetchFollowing(page: 2);
      firestore.release.complete();
      expect((await old).isFailure, isTrue);
      expect((await repository.fetchFollowing(page: 3)).data!.items.first.id, 'W24');
    });
    test('an unknown block list does not fail a Following page that has no rows', () async {
      app_state.prismUser = _signedInUser();
      final firestore = _FollowingGraphFirestore()..followedUid = null;
      final repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: _UnknownBlocks(),
      );

      final result = await repository.fetchFollowing(page: 1);

      expect(result.isSuccess, isTrue);
      expect(result.data!.items, isEmpty);
    });

    test('Following without follows completes with a hanging block loader without advancing time', () {
      fakeAsync((async) {
        app_state.prismUser = _signedInUser();
        final _FollowingFirestore firestore = _FollowingFirestore(rows: 3)..followed = const <String>[];
        final _EmptyBlocks blocks = _EmptyBlocks()..hangOnWait = true;
        final PersonalizedFeedRepository repository = _repository(
          firestore: firestore,
          settings: SettingsLocalDataSource(InMemoryLocalStore()),
          favourites: _CountingFavourites(),
          blocks: blocks,
        );
        Result<PersonalizedFeedPage>? result;
        repository.fetchFollowing(page: 1).then((value) => result = value);

        async.flushMicrotasks();

        expect(result?.isSuccess, isTrue);
        expect(result?.data?.items, isEmpty);
        expect(result?.data?.hasMore, isFalse);
        expect(firestore.limits, isEmpty);
      });
    });

    test('Following with follows but zero walls completes with a hanging block loader without advancing time', () {
      fakeAsync((async) {
        app_state.prismUser = _signedInUser(following: const <String>['a-uid']);
        final _FollowingFirestore firestore = _FollowingFirestore(rows: 0);
        final _EmptyBlocks blocks = _EmptyBlocks()..hangOnWait = true;
        final PersonalizedFeedRepository repository = _repository(
          firestore: firestore,
          settings: SettingsLocalDataSource(InMemoryLocalStore()),
          favourites: _CountingFavourites(),
          blocks: blocks,
        );
        Result<PersonalizedFeedPage>? result;
        repository.fetchFollowing(page: 1).then((value) => result = value);

        async.flushMicrotasks();

        expect(result?.isSuccess, isTrue);
        expect(result?.data?.items, isEmpty);
        expect(result?.data?.hasMore, isFalse);
        expect(firestore.limits, <int>[12]);
      });
    });

    test('an exhausted Following page completes with a hanging block loader without advancing time', () {
      fakeAsync((async) {
        app_state.prismUser = _signedInUser(following: const <String>['a-uid']);
        final _FollowingFirestore firestore = _FollowingFirestore(rows: 3);
        final _EmptyBlocks blocks = _EmptyBlocks();
        final PersonalizedFeedRepository repository = _repository(
          firestore: firestore,
          settings: SettingsLocalDataSource(InMemoryLocalStore()),
          favourites: _CountingFavourites(),
          blocks: blocks,
        );
        Result<PersonalizedFeedPage>? first;
        repository.fetchFollowing(page: 1).then((value) => first = value);
        async.flushMicrotasks();
        expect(first?.isSuccess, isTrue);
        expect(first?.data?.items.map((item) => item.id), <String>['W0', 'W1', 'W2']);
        expect(first?.data?.hasMore, isFalse);
        expect(firestore.limits, <int>[12]);
        blocks.hangOnWait = true;

        Result<PersonalizedFeedPage>? exhausted;
        repository.fetchFollowing(page: 2).then((value) => exhausted = value);
        async.flushMicrotasks();

        expect(exhausted?.isSuccess, isTrue);
        expect(exhausted?.data?.items, isEmpty);
        expect(exhausted?.data?.hasMore, isFalse);
        expect(firestore.limits, <int>[12]);
      });
    });

    test('an unknown block list on a later Following page keeps its cursor for the retry', () async {
      app_state.prismUser = _signedInUser(following: const <String>['a-uid']);
      final firestore = _FollowingFirestore(rows: 57);
      final blocks = _BlocksLoadedLater()..listLoaded = true;
      final repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: blocks,
      );
      final first = (await repository.fetchFollowing(page: 1)).data!;
      expect(first.items.map((item) => item.id), List<String>.generate(12, (i) => 'W$i'));

      blocks.listLoaded = false;
      expect((await repository.fetchFollowing(page: 2)).isFailure, isTrue);
      blocks.listLoaded = true;
      final second = (await repository.fetchFollowing(page: 2)).data!;

      expect(second.items.map((item) => item.id), List<String>.generate(12, (i) => 'W${i + 12}'));
    });

    test('an unknown block list on a refresh keeps the last committed cursor', () async {
      app_state.prismUser = _signedInUser(following: const <String>['a-uid']);
      final firestore = _FollowingFirestore(rows: 57);
      final blocks = _BlocksLoadedLater()..listLoaded = true;
      final repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: blocks,
      );
      final first = (await repository.fetchFollowing(page: 1)).data!;
      expect(first.items.map((item) => item.id), List<String>.generate(12, (i) => 'W$i'));

      blocks.listLoaded = false;
      expect((await repository.fetchFollowing(page: 1)).isFailure, isTrue);
      blocks.listLoaded = true;
      final second = (await repository.fetchFollowing(page: 2)).data!;

      expect(second.items.map((item) => item.id), List<String>.generate(12, (i) => 'W${i + 12}'));
    });

    test('cursor pages reach all 57 walls once without growing query limits', () async {
      app_state.prismUser = _signedInUser(following: const <String>['a-uid']);
      final firestore = _FollowingFirestore(rows: 57);
      final repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );
      final ids = <String>[];
      for (int page = 1; page <= 10; page++) {
        final result = (await repository.fetchFollowing(page: page)).data!;
        expect(result.items.length, lessThanOrEqualTo(12));
        ids.addAll(result.items.map((item) => item.id));
        if (!result.hasMore) break;
      }
      expect(ids, List<String>.generate(57, (i) => 'W$i'));
      expect(firestore.limits.every((limit) => limit == 12), isTrue);
    });

    test('loaded empty following is authoritative after bootstrap and owner changes', () async {
      app_state.prismUser = _signedInUser();
      final firestore = _FollowingFirestore(rows: 3);
      final repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );
      await repository.fetch(_firstPage);
      firestore.followed = const <String>[];
      final calls = firestore.limits.length;
      expect((await repository.fetchFollowing(page: 1)).data!.items, isEmpty);
      await repository.fetch(_firstPage);
      expect(firestore.limits, hasLength(calls));
      firestore.followed = const <String>['a-uid'];
      await repository.fetch(_firstPage);
      final ownerCalls = firestore.limits.length;
      app_state.prismUser = _signedInUser(id: 'replacement-owner');
      expect((await repository.fetchFollowing(page: 1)).data!.items, isEmpty);
      expect(firestore.limits, hasLength(ownerCalls));
      app_state.prismUser = app_constants.createGuestPrismUser();
      expect((await repository.fetchFollowing(page: 1)).data!.items, isEmpty);
    });
    test('returns the followed creators walls and reports that more may follow', () async {
      app_state.prismUser = _signedInUser(following: const <String>['a-uid']);
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
      app_state.prismUser = _signedInUser(following: const <String>['a-uid']);
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
      final _FollowingFirestore firestore = _FollowingFirestore(rows: 3)..followed = const <String>[];
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
      app_state.prismUser = _signedInUser(following: const <String>['a-uid']);
      final _FollowingFirestore firestore = _FollowingFirestore(rows: 2, email: 'blocked@example.com');
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: _BlockingBlocks(<String>{'a-uid'}),
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

    test('fails instead of an empty page while the block list is unknown', () async {
      final _PopularFirestore firestore = _PopularFirestore(
        popularIds: <String>['AAA'],
        walls: <String>['AAA'],
        creatorUid: 'creator-uid',
      );
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: _UnknownBlocks(),
      );

      expect((await repository.fetchPopular()).isFailure, isTrue);
    });

    test('fails an unknown mixed page, then restores its ordered walls once blocks load', () async {
      final _PopularFirestore firestore = _PopularFirestore(
        popularIds: <String>['CREATORLESS', 'BLOCKED', 'VISIBLE'],
        walls: <String>['CREATORLESS', 'BLOCKED', 'VISIBLE'],
        creatorUids: <String, String>{'BLOCKED': 'blocked-uid', 'VISIBLE': 'visible-uid'},
      );
      final _BlocksLoadedLater blocks = _BlocksLoadedLater();
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: blocks,
      );

      final firstResult = await repository.fetchPopular();
      expect(firstResult.isFailure, isTrue);
      expect(firstResult.data, isNull);

      blocks.listLoaded = true;
      final retryResult = await repository.fetchPopular();
      expect(retryResult.data!.items.map((item) => item.id), <String>['CREATORLESS', 'BLOCKED', 'VISIBLE']);
      expect(retryResult.data!.hasMore, isFalse);
    });

    test('keeps walls without a creator while the block list is unknown', () async {
      final _PopularFirestore firestore = _PopularFirestore(popularIds: <String>['AAA'], walls: <String>['AAA']);
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: _UnknownBlocks(),
      );

      expect((await repository.fetchPopular()).data!.items.map((item) => item.id), <String>['AAA']);
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

    test('falls back when the popular document has an empty wallIds list', () async {
      final _PopularFirestore firestore = _PopularFirestore(
        popularDocExists: true,
        statsIds: <String>['AAA'],
        walls: <String>['AAA'],
      );
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
      );

      expect((await repository.fetchPopular()).data!.items.map((item) => item.id), <String>['AAA']);
      expect(firestore.sourceTags, contains('popular.stats'));
    });

    test('fails unknown stats fallback rows that have creators', () async {
      final _PopularFirestore firestore = _PopularFirestore(
        statsIds: <String>['AAA'],
        walls: <String>['AAA'],
        creatorUid: 'creator-uid',
      );
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: _UnknownBlocks(),
      );

      final result = await repository.fetchPopular();
      expect(result.isFailure, isTrue);
      expect(result.data, isNull);
    });

    test('keeps creatorless stats fallback rows when blocks are unknown', () async {
      final _PopularFirestore firestore = _PopularFirestore(statsIds: <String>['AAA'], walls: <String>['AAA']);
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: _UnknownBlocks(),
      );

      expect((await repository.fetchPopular()).data!.items.map((item) => item.id), <String>['AAA']);
    });

    test('returns an empty page when popular and stats are empty even if blocks are unknown', () async {
      final PersonalizedFeedRepository repository = _repository(
        firestore: _PopularFirestore(),
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: _UnknownBlocks(),
      );

      final result = await repository.fetchPopular();
      expect(result.data!.items, isEmpty);
      expect(result.data!.hasMore, isFalse);
    });

    test('hides only blocked creators from a known mixed page', () async {
      final _PopularFirestore firestore = _PopularFirestore(
        popularIds: <String>['CREATORLESS', 'BLOCKED', 'VISIBLE'],
        walls: <String>['CREATORLESS', 'BLOCKED', 'VISIBLE'],
        creatorUids: <String, String>{'BLOCKED': 'blocked-uid', 'VISIBLE': 'visible-uid'},
      );
      final PersonalizedFeedRepository repository = _repository(
        firestore: firestore,
        settings: SettingsLocalDataSource(InMemoryLocalStore()),
        favourites: _CountingFavourites(),
        blocks: _BlockingBlocks(<String>{'blocked-uid'}),
      );

      expect((await repository.fetchPopular()).data!.items.map((item) => item.id), <String>['CREATORLESS', 'VISIBLE']);
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
  OfflineWallpaperCatalog? offlineCatalog,
  DateTime Function()? now,
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
    offlineCatalog: offlineCatalog,
    now: now,
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

FeedItemEntity _prismItem(String id, {String authorUid = 'creator-id', List<String>? tags, bool ai = false}) =>
    FeedItemEntity.prism(
      id: id,
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: id,
          source: WallpaperSource.prism,
          fullUrl: 'https://example.com/$id.jpg',
          thumbnailUrl: 'https://example.com/$id-thumb.jpg',
          authorUid: authorUid,
        ),
        tags: tags,
        isAiGenerated: ai,
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
  Future<BlockedCreators> loadBlockedCreators() async => KnownBlockedCreators(cached);
}

class _UnknownBlocks extends _EmptyBlocks {
  @override
  BlockedCreators get blockedCreators => const UnknownBlockedCreators();

  @override
  Future<BlockedCreators> loadBlockedCreators() async => const UnknownBlockedCreators();
}

/// Unknown until [loaded] is set, then an empty known list.
class _BlocksLoadedLater extends _EmptyBlocks {
  bool listLoaded = false;

  @override
  BlockedCreators get blockedCreators =>
      listLoaded ? KnownBlockedCreators(const <String>{}) : const UnknownBlockedCreators();

  @override
  Future<BlockedCreators> loadBlockedCreators() async => blockedCreators;
}

class _FollowingGraphFirestore extends _EmptyFirestore {
  String? followedUid = 'creator-uid';
  int followGraphReads = 0;
  final List<FirestoreQuerySpec> specs = <FirestoreQuerySpec>[];

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    specs.add(spec);
    if (spec.collection == 'profiles/feed-test-user/following') {
      followGraphReads++;
      final String? uid = followedUid;
      return uid == null ? <T>[] : <T>[map(<String, dynamic>{}, uid)];
    }
    if (spec.collection == 'walls') {
      return <T>[
        map(<String, dynamic>{..._OneWallFirestore._wall, 'creatorUid': followedUid}, 'wall-for-$followedUid'),
      ];
    }
    return <T>[];
  }
}

/// Answers the creator query with [rows] walls and records the limit it was asked for.
class _FollowingFirestore extends _EmptyFirestore {
  _FollowingFirestore({required this.rows, this.email = 'a@example.com'});

  final int rows;
  final String email;
  bool fail = false;
  List<String> followed = const <String>['a-uid'];
  final List<int> limits = <int>[];

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    if (spec.collection == 'profiles/feed-test-user/following') {
      return <T>[for (final uid in followed) map(<String, dynamic>{}, uid)];
    }
    if (!spec.sourceTag.startsWith('personalized.creator_chunk_')) {
      return <T>[];
    }
    if (fail) {
      throw StateError('offline');
    }
    limits.add(spec.limit!);
    final start = spec.startAfterDocId == null ? 0 : int.parse(spec.startAfterDocId!.substring(3)) + 1;
    return <T>[
      for (int i = start; i < rows && i < start + spec.limit!; i++)
        map(<String, dynamic>{
          'id': 'W$i',
          'wallpaper_url': 'https://example.com/w$i.jpg',
          'wallpaper_thumb': 'https://example.com/w$i-thumb.jpg',
          'wallpaper_provider': 'prism',
          'review': true,
          'creatorUid': 'a-uid',
          'email': email,
          'createdAt': '2026-09-01T00:00:00Z',
        }, 'doc$i'),
    ];
  }
}

class _DelayedFollowingFirestore extends _FollowingFirestore {
  _DelayedFollowingFirestore({required super.rows});
  final started = Completer<void>();
  final release = Completer<void>();
  bool delayed = false;

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic>, String) map) async {
    final rows = await super.query(spec, map);
    if (!delayed) {
      delayed = true;
      started.complete();
      await release.future;
    }
    return rows;
  }
}

class _ChunkedFollowingFirestore extends _EmptyFirestore {
  _ChunkedFollowingFirestore({this.sameDate = false});
  final bool sameDate;
  final specs = <FirestoreQuerySpec>[];

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic>, String) map) async {
    specs.add(spec);
    if (spec.collection == 'profiles/feed-test-user/following') {
      return <T>[for (int i = 0; i < 11; i++) map(<String, dynamic>{}, 'c${i.toString().padLeft(2, '0')}')];
    }
    final uids = spec.filters.firstWhere((filter) => filter.field == 'creatorUid').value! as List<String>;
    final all = <int>[
      for (int i = 0; i < 62; i++)
        if (uids.contains(i % 13 == 0 ? 'c10' : 'c00')) i,
    ];
    if (sameDate) all.sort((a, b) => b.compareTo(a));
    final cursor = spec.startAfterDocId == null ? null : int.parse(spec.startAfterDocId!.substring(3));
    final indexes = all.skip(cursor == null ? 0 : all.indexOf(cursor) + 1).take(spec.limit!);
    return <T>[
      for (final i in indexes)
        map(<String, dynamic>{
          'id': 'W$i',
          'wallpaper_url': 'https://example.com/$i',
          'review': true,
          'creatorUid': i % 13 == 0 ? 'c10' : 'c00',
          'createdAt': DateTime.utc(2026).subtract(Duration(minutes: sameDate ? 0 : i)).toIso8601String(),
        }, 'doc${i.toString().padLeft(3, '0')}'),
    ];
  }
}

class _PopularFirestore extends _EmptyFirestore {
  _PopularFirestore({
    this.popularIds = const <String>[],
    this.statsIds = const <String>[],
    this.popularFails = false,
    this.popularDocExists = false,
    this.walls = const <String>[],
    this.creatorUid,
    this.creatorUids = const <String, String>{},
  });

  final String? creatorUid;
  final Map<String, String> creatorUids;
  final List<String> popularIds;
  final List<String> statsIds;
  final bool popularFails;
  final bool popularDocExists;
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
    return popularIds.isEmpty && !popularDocExists ? null : map(<String, dynamic>{'wallIds': popularIds}, id);
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
            'creatorUid': ?(creatorUids[id] ?? creatorUid),
          }, 'doc-$id'),
    ];
  }
}
