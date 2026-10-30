// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
import 'package:Prism/features/category_feed/data/feed_item_cache_codec.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/domain/repositories/drops_repository.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_walls_repository.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/data/feed_impression_store.dart';
import 'package:Prism/features/personalized_feed/data/personalized_feed_repository_impl.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:Prism/features/personalized_feed/domain/usecases/personalized_feed_usecases.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_user_block_repository.dart';
import '../../../../support/in_memory_local_store.dart';

class _MemoryFeedCache extends FeedCacheLocalDataSource {
  _MemoryFeedCache(this.snapshot);

  final FeedSnapshot? snapshot;

  @override
  Future<FeedSnapshot?> read({required String source, required String scope}) async => snapshot;

  @override
  Future<void> write({
    required String source,
    required String scope,
    required Object? payload,
    required int ttlHours,
  }) async {}
}

class _SequencedFirestore extends Fake implements FirestoreClient {
  int freshCalls = 0;
  Completer<void>? firstFreshGate;
  Completer<void>? firstFreshStarted;

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic>, String) map) async {
    if (spec.sourceTag != 'personalized.fresh') return <T>[];
    final int call = ++freshCalls;
    if (call == 1 && firstFreshGate != null) {
      firstFreshStarted?.complete();
      await firstFreshGate!.future;
    }
    final String id = call == 1 && firstFreshGate != null ? 'older-result' : 'primed-result';
    return <T>[
      map(<String, dynamic>{
        'wallpaper_url': 'https://example.com/$id.jpg',
        'wallpaper_thumb': 'https://example.com/$id-thumb.jpg',
        'wallpaper_provider': 'prism',
        'review': true,
        'email': '$id@example.com',
        'creatorUid': '$id-creator',
        'createdAt': '2026-09-01T00:00:00Z',
      }, id),
    ];
  }

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic>, String) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async => null;
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

class _EmptyFavourites extends Fake implements FavouriteWallsRepository {
  @override
  Future<Result<List<FavouriteWallEntity>>> fetchFavourites({required String userId}) async =>
      Result.success(<FavouriteWallEntity>[]);
}

class _EmptyBlocks extends Fake implements UserBlockRepository {
  @override
  BlockedCreators get blockedCreators => KnownBlockedCreators(const <String>{});

  @override
  Future<BlockedCreators> loadBlockedCreators() async => KnownBlockedCreators(const <String>{});
}

class _NoopOfflineCatalog extends OfflineWallpaperCatalog {
  @override
  Future<void> remember(Iterable<FeedItemEntity> items) async {}
}

class _EmptyDrops extends Fake implements DropsRepository {
  @override
  Future<Result<DropEntity?>> fetchLive(DateTime now) async => Result.success<DropEntity?>(null);
}

FeedItemEntity _item(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: 'https://example.com/$id-thumb.jpg',
      authorUid: '$id-creator',
    ),
  ),
);

({PersonalizedFeedRepositoryImpl repository, SettingsLocalDataSource settings, FeedImpressionStore impressions})
_buildRepository({required _SequencedFirestore firestore, FeedSnapshot? cached}) {
  final settings = SettingsLocalDataSource(InMemoryLocalStore());
  final impressions = FeedImpressionStore(settings);
  return (
    repository: PersonalizedFeedRepositoryImpl(
      firestore,
      _MemoryFeedCache(cached),
      settings,
      _EmptyWallhaven(),
      _EmptyPexels(),
      _EmptyBlocks(),
      _EmptyFavourites(),
      TasteSignalStore(settings),
      impressions,
      offlineCatalog: _NoopOfflineCatalog(),
    ),
    settings: settings,
    impressions: impressions,
  );
}

FeedSnapshot _snapshot(List<FeedItemEntity> items) => FeedSnapshot(
  payload: <String, Object?>{'items': items.map(encodeFeedItem).toList(growable: false)},
  cachedAtUtc: DateTime.now().toUtc(),
  ttlHours: 2,
);

void main() {
  setUp(() => app_state.prismUser = createGuestPrismUser());
  tearDown(() {
    app_state.prismUser = createGuestPrismUser();
    AnalyticsRuntime.reset();
    EconomyConfig.current = EconomyConfig.defaults;
  });

  test('started paints the primed page before replacing the warm cache page', () async {
    final env = _buildRepository(
      firestore: _SequencedFirestore(),
      cached: _snapshot(<FeedItemEntity>[_item('old-cache')]),
    );
    env.repository.warmCache();
    final PersonalizedFeedPage? primed = await env.repository.primeFirstPage();
    final bloc = PersonalizedFeedBloc(
      FetchPersonalizedFeedUseCase(env.repository),
      env.repository,
      FakeUserBlockRepository.pending()..completeInitial(<String>{}),
      _EmptyDrops(),
    );
    addTearDown(bloc.close);

    final List<List<String>> visiblePages = <List<String>>[];
    final subscription = bloc.stream.listen((state) {
      if (state.items.isNotEmpty) visiblePages.add(state.items.map((item) => item.id).toList());
    });
    addTearDown(subscription.cancel);

    bloc.add(const PersonalizedFeedEvent.started());
    await bloc.stream.firstWhere((state) => state.status == LoadStatus.success && !state.isRefreshing);

    expect(primed?.items.map((item) => item.id), <String>['primed-result']);
    expect(visiblePages.first, <String>['primed-result']);
    expect(bloc.state.items.map((item) => item.id), <String>['primed-result']);
  });

  test('settings handoff beats a pending refresh and records only the visible prime impressions', () async {
    final firestore = _SequencedFirestore()
      ..firstFreshGate = Completer<void>()
      ..firstFreshStarted = Completer<void>();
    final env = _buildRepository(firestore: firestore);
    final bloc = PersonalizedFeedBloc(
      FetchPersonalizedFeedUseCase(env.repository),
      env.repository,
      FakeUserBlockRepository.pending()..completeInitial(<String>{}),
      _EmptyDrops(),
    );
    addTearDown(bloc.close);

    bloc.add(const PersonalizedFeedEvent.refreshRequested());
    await firestore.firstFreshStarted!.future;
    await env.settings.set(personalizedFeedMixLocalKey, 'adventurous');
    await TasteSignalStore(
      env.settings,
    ).record(TasteSignal(action: TasteAction.open, at: DateTime.now().toUtc(), terms: const <String>['nature']));
    final PersonalizedFeedPage? primed = await env.repository.primeFirstPage();
    expect(primed?.items.map((item) => item.id), <String>['primed-result']);

    bloc.add(const PersonalizedFeedEvent.settingsChanged());
    await bloc.stream.firstWhere((state) => state.status == LoadStatus.success && !state.isRefreshing);
    firestore.firstFreshGate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(bloc.state.items.map((item) => item.id), <String>['primed-result']);
    final keys = primed!.items.map((item) => item.canonicalKey).toList(growable: false);
    bloc.add(PersonalizedFeedEvent.tilesSeen(keys));
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(env.impressions.recentShows(DateTime.now().toUtc()), <String, int>{for (final key in keys) key: 1});
    expect(firestore.freshCalls, 2);
  });
}
