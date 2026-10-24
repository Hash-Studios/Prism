import 'dart:async';
import 'dart:io';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/data/prism_wall_search.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../../support/fake_firestore_client.dart';
import '../../support/fake_user_block_repository.dart';
import '../../support/in_memory_local_store.dart';

class _FakeWallhavenRepository implements WallhavenWallpaperRepository {
  _FakeWallhavenRepository(this.result, {this.delay = Duration.zero});

  final Result<List<WallhavenWallpaper>> result;
  final Duration delay;
  int? lastCategories;
  int? lastPurity;
  bool? lastRefresh;
  bool? lastPortraitOnly;
  String? lastMinResolution;
  String? lastSorting;
  String? lastPaginationKey;
  String? lastCategoryName;
  String? lastColors;
  int calls = 0;

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
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    lastCategoryName = categoryName;
    lastColors = colors;
    lastCategories = categories;
    lastPurity = purity;
    lastRefresh = refresh;
    lastPortraitOnly = portraitOnly;
    lastMinResolution = minResolution;
    lastSorting = sorting;
    lastPaginationKey = paginationKey;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePexelsRepository implements PexelsWallpaperRepository {
  _FakePexelsRepository(this.result);

  final Result<List<PexelsWallpaper>> result;
  bool? lastPortraitOnly;
  String? lastPaginationKey;
  String? lastColor;
  int calls = 0;

  @override
  Future<Result<List<PexelsWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int startPage = 1,
    String? paginationKey,
    bool portraitOnly = true,
    String? color,
  }) async {
    calls++;
    lastColor = color;
    lastPortraitOnly = portraitOnly;
    lastPaginationKey = paginationKey;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedPrismFirestore extends FakeFirestoreClient {
  _DelayedPrismFirestore(this.delay, {super.onQuery});

  final Duration delay;

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    if (spec.sourceTag.startsWith('PrismWallSearch')) await Future<void>.delayed(delay);
    return super.query(spec, map);
  }
}

WallhavenWallpaper _wallhaven(String id) => WallhavenWallpaper(
  core: WallpaperCore(id: id, source: WallpaperSource.wallhaven, fullUrl: 'https://w/$id.jpg', thumbnailUrl: 't'),
);

PexelsWallpaper _pexels(String id, {String? resolution}) => PexelsWallpaper(
  core: WallpaperCore(
    id: id,
    source: WallpaperSource.pexels,
    fullUrl: 'https://p/$id.jpg',
    thumbnailUrl: 't',
    resolution: resolution,
  ),
);

WallpaperSearchService _service({
  required Result<List<WallhavenWallpaper>> wallhaven,
  Result<List<PexelsWallpaper>>? pexels,
  InMemoryLocalStore? store,
  _FakeWallhavenRepository? wallhavenRepository,
  _FakePexelsRepository? pexelsRepository,
  FakeFirestoreClient? firestore,
}) {
  return WallpaperSearchService(
    wallhavenRepository ?? _FakeWallhavenRepository(wallhaven),
    pexelsRepository ?? _FakePexelsRepository(pexels ?? Result.success(<PexelsWallpaper>[])),
    SettingsLocalDataSource(store ?? InMemoryLocalStore()),
    PrismWallSearch(firestore ?? FakeFirestoreClient(), FakeUserBlockRepository.pending()..completeInitial(<String>{})),
  );
}

Map<String, dynamic> _prismDoc(
  String id, {
  String resolution = '1080x2400',
  String creatorUid = 'creator-id',
  List<String> colors = const <String>[],
  String? depthTier,
  String? category,
}) => <String, dynamic>{
  'id': id,
  'wallpaper_url': 'https://prism/$id.jpg',
  'wallpaper_thumb': 'https://prism/$id-thumb.jpg',
  'wallpaper_provider': 'prism',
  'resolution': resolution,
  'creatorUid': creatorUid,
  'review': true,
  'colors': colors,
  'depth': ?(depthTier == null ? null : <String, dynamic>{'tier': depthTier}),
  'category': ?category,
};

void main() {
  test('a slow remote search succeeds when there is no saved fallback', () async {
    final repository = _FakeWallhavenRepository(
      Result.success(<WallhavenWallpaper>[_wallhaven('slow')]),
      delay: const Duration(seconds: 4),
    );
    final service = _service(wallhaven: Result.success(<WallhavenWallpaper>[]), wallhavenRepository: repository);

    final page = await service.search('mountain');

    expect(page.results.map((wall) => wall.id), <String>['slow']);
    expect(page.isLocal, isFalse);
    expect(repository.calls, 1);
  });

  test('slow successful Prism search results are retained when the local catalog is empty', () async {
    final FakeFirestoreClient firestore = _DelayedPrismFirestore(
      const Duration(seconds: 4),
      onQuery: (spec) => spec.sourceTag == 'PrismWallSearch.terms'
          ? <FakeDocRow>[(id: 'prism-slow', data: _prismDoc('prism-slow'))]
          : const <FakeDocRow>[],
    );
    final service = _service(wallhaven: Result.success(<WallhavenWallpaper>[]), firestore: firestore);

    final page = await service.search('mountain');

    expect(page.prismResults.map((item) => item.id), <String>['prism-slow']);
  });

  test('saved search results return at the short decision budget', () async {
    final Directory directory = await Directory.systemTemp.createTemp('wallpaper-search-catalog-');
    addTearDown(() => directory.delete(recursive: true));
    final OfflineWallpaperCatalog catalog = OfflineWallpaperCatalog(
      store: DurableJsonStore('catalog', directory: directory),
    );
    await catalog.remember(<FeedItemEntity>[WallhavenFeedItem(id: 'saved', wallpaper: _wallhaven('saved'))]);
    final repository = _FakeWallhavenRepository(
      Result.success(<WallhavenWallpaper>[_wallhaven('remote')]),
      delay: const Duration(seconds: 4),
    );
    final service = WallpaperSearchService(
      repository,
      _FakePexelsRepository(Result.success(<PexelsWallpaper>[])),
      SettingsLocalDataSource(InMemoryLocalStore()),
      PrismWallSearch(FakeFirestoreClient(), FakeUserBlockRepository.pending()..completeInitial(<String>{})),
      catalog,
    );

    final Stopwatch stopwatch = Stopwatch()..start();
    final page = await service.search('saved');

    expect(page.results.map((wall) => wall.id), <String>['saved']);
    expect(page.isLocal, isTrue);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 4)));
    expect(repository.calls, 1);
  });

  test('providers start while the local catalog scan is still waiting', () async {
    final Directory directory = await Directory.systemTemp.createTemp('wallpaper-search-slow-catalog-');
    addTearDown(() => directory.delete(recursive: true));
    final Completer<Set<String>> blocked = Completer<Set<String>>();
    final OfflineWallpaperCatalog catalog = OfflineWallpaperCatalog(
      store: DurableJsonStore('catalog', directory: directory),
      blockedUids: () => blocked.future,
    );
    await catalog.remember(<FeedItemEntity>[WallhavenFeedItem(id: 'saved', wallpaper: _wallhaven('saved'))]);
    final repository = _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[_wallhaven('remote')]));
    final firestore = FakeFirestoreClient();
    final service = WallpaperSearchService(
      repository,
      _FakePexelsRepository(Result.success(<PexelsWallpaper>[])),
      SettingsLocalDataSource(InMemoryLocalStore()),
      PrismWallSearch(firestore, FakeUserBlockRepository.pending()..completeInitial(<String>{})),
      catalog,
    );

    final Future<WallpaperSearchPage> search = service.search('saved');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repository.calls, 1);
    expect(firestore.querySpecs, isNotEmpty);

    blocked.complete(<String>{});
    final page = await search;
    expect(page.results.map((wall) => wall.id), <String>['remote']);
  });

  group('repeated search', () {
    tearDown(() async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      await GetIt.instance.reset();
    });

    test('changing saved content settings does not reuse the previous first page', () async {
      final repository = _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[_wallhaven('a')]));
      final store = InMemoryLocalStore();
      final settings = SettingsLocalDataSource(store);
      final service = _service(wallhaven: repository.result, wallhavenRepository: repository, store: store);

      await service.search('nature');
      await settings.set('WHcategories', 111);
      await service.search('nature');
      expect(repository.calls, 2);
      expect(repository.lastCategories, 111);

      await settings.set('WHpurity', 110);
      await service.search('nature');
      expect(repository.calls, 3);
      expect(repository.lastPurity, 110);
    });

    test('a whitespace-equivalent cache hit keeps the same provider cursor', () async {
      final repository = _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[_wallhaven('a')]));
      final service = _service(wallhaven: repository.result, wallhavenRepository: repository);

      await service.search('nature');
      await service.search(' nature ');
      await service.fetchPage(SearchProviderValue.wallhaven, ' nature ', refresh: false);

      expect(repository.calls, 2);
      expect(repository.lastPaginationKey, 'search:nature');
      expect(repository.lastCategoryName, 'nature');
    });

    test('unblocking a creator restores Prism results excluded before caching', () async {
      final blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{'creator-id'});
      final firestore = FakeFirestoreClient(
        onQuery: (spec) => <FakeDocRow>[(id: 'p1', data: _prismDoc('p1', creatorUid: 'creator-id'))],
      );
      GetIt.instance.registerSingleton<UserBlockRepository>(blocks);
      final service = WallpaperSearchService(
        _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[_wallhaven('a')])),
        _FakePexelsRepository(Result.success(<PexelsWallpaper>[])),
        SettingsLocalDataSource(InMemoryLocalStore()),
        PrismWallSearch(firestore, blocks),
      );

      expect((await service.search('nature')).prismResults, isEmpty);
      blocks.completeInitial(<String>{});

      expect((await service.search('nature')).prismResults.map((wall) => wall.id), <String>['p1']);
    });

    test('switching accounts does not retain the previous account Prism omissions', () async {
      final blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
      int prismCalls = 0;
      final firestore = FakeFirestoreClient(
        onQuery: (spec) {
          if (spec.sourceTag == 'PrismWallSearch.terms') {
            prismCalls++;
            return prismCalls == 1 ? const <FakeDocRow>[] : <FakeDocRow>[(id: 'p1', data: _prismDoc('p1'))];
          }
          return const <FakeDocRow>[];
        },
      );
      final repository = _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[_wallhaven('a')]));
      final service = WallpaperSearchService(
        repository,
        _FakePexelsRepository(Result.success(<PexelsWallpaper>[])),
        SettingsLocalDataSource(InMemoryLocalStore()),
        PrismWallSearch(firestore, blocks),
      );

      app_state.prismUser = app_constants.createGuestPrismUser()..id = 'first-account';
      expect((await service.search('nature')).prismResults, isEmpty);
      app_state.prismUser = app_constants.createGuestPrismUser()..id = 'second-account';

      expect((await service.search('nature')).prismResults.map((wall) => wall.id), <String>['p1']);
      expect(repository.calls, 2);
    });

    test('a cached page waits for the active block list before returning creators', () async {
      final initialBlocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
      GetIt.instance.registerSingleton<UserBlockRepository>(initialBlocks);
      final firestore = FakeFirestoreClient(
        onQuery: (spec) => <FakeDocRow>[(id: 'p1', data: _prismDoc('p1', creatorUid: 'creator-id'))],
      );
      final service = WallpaperSearchService(
        _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[_wallhaven('a')])),
        _FakePexelsRepository(Result.success(<PexelsWallpaper>[])),
        SettingsLocalDataSource(InMemoryLocalStore()),
        PrismWallSearch(firestore, initialBlocks),
      );
      await service.search('nature');
      await GetIt.instance.unregister<UserBlockRepository>();
      final pendingBlocks = FakeUserBlockRepository.pending();
      GetIt.instance.registerSingleton<UserBlockRepository>(pendingBlocks);
      bool returned = false;
      final result = service.search('nature').then((page) {
        returned = true;
        return page;
      });
      await Future<void>.delayed(Duration.zero);
      final bool returnedBeforeBlocks = returned;
      pendingBlocks.completeInitial(<String>{'creator-id'});
      final page = await result;

      expect(returnedBeforeBlocks, isFalse);
      expect(page.prismResults, isEmpty);
    });

    test('a repeated identical search makes no provider call and returns the same results', () async {
      final repository = _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[_wallhaven('a')]));
      final firestore = FakeFirestoreClient(
        onQuery: (spec) => spec.sourceTag == 'PrismWallSearch.terms'
            ? <FakeDocRow>[(id: 'd1', data: _prismDoc('p1'))]
            : const <FakeDocRow>[],
      );
      final service = _service(wallhaven: repository.result, wallhavenRepository: repository, firestore: firestore);

      final first = await service.search('mountain');
      final queriesAfterFirst = firestore.querySpecs.length;
      final second = await service.search(' mountain ');

      expect(repository.calls, 1);
      expect(firestore.querySpecs.length, queriesAfterFirst);
      expect(second.results.map((wall) => wall.id), first.results.map((wall) => wall.id));
      expect(second.prismResults.map((wall) => wall.id), <String>['p1']);
    });

    test('a different filter searches again', () async {
      final repository = _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[_wallhaven('a')]));
      final service = _service(wallhaven: repository.result, wallhavenRepository: repository);

      await service.search('mountain');
      await service.search('mountain', filters: const SearchFilters(sort: SearchSort.latest));

      expect(repository.calls, 2);
    });

    test('load-more after a cached hit asks for the next page, not the first', () async {
      final repository = _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[_wallhaven('a')]));
      final service = _service(wallhaven: repository.result, wallhavenRepository: repository);

      await service.search('mountain');
      await service.search('mountain');
      await service.fetchPage(SearchProviderValue.wallhaven, 'mountain', refresh: false);

      expect(repository.calls, 2);
      expect(repository.lastRefresh, isFalse);
      expect(repository.lastPaginationKey, 'search:mountain');
    });

    test('a search after load-more starts from the first page again', () async {
      final repository = _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[_wallhaven('a')]));
      final service = _service(wallhaven: repository.result, wallhavenRepository: repository);

      await service.search('mountain');
      await service.fetchPage(SearchProviderValue.wallhaven, 'mountain', refresh: false);
      await service.search('mountain');

      expect(repository.calls, 3);
      expect(repository.lastRefresh, isTrue);
    });

    test('a cached hit hides creators blocked after it was stored', () async {
      final firestore = FakeFirestoreClient(
        onQuery: (spec) => <FakeDocRow>[(id: 'd1', data: _prismDoc('p1', creatorUid: 'later-id'))],
      );
      Set<String> blocked = <String>{};
      final service = WallpaperSearchService(
        _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[_wallhaven('a')])),
        _FakePexelsRepository(Result.success(<PexelsWallpaper>[])),
        SettingsLocalDataSource(InMemoryLocalStore()),
        PrismWallSearch(firestore, FakeUserBlockRepository.pending()..completeInitial(<String>{})),
        null,
        () => blocked,
      );

      expect((await service.search('nature')).prismResults.map((wall) => wall.id), <String>['p1']);
      blocked = <String>{'later-id'};

      expect((await service.search('nature')).prismResults, isEmpty);
    });

    test('anime Prism walls are hidden while the anime setting is off', () async {
      final store = InMemoryLocalStore();
      final firestore = FakeFirestoreClient(
        onQuery: (spec) => spec.sourceTag == 'PrismWallSearch.terms'
            ? <FakeDocRow>[(id: 'd1', data: _prismDoc('p1', category: 'Anime')), (id: 'd2', data: _prismDoc('p2'))]
            : const <FakeDocRow>[],
      );
      final service = _service(
        wallhaven: Result.success(<WallhavenWallpaper>[_wallhaven('a')]),
        store: store,
        firestore: firestore,
      );

      expect((await service.search('girl')).prismResults.map((wall) => wall.id), <String>['p2']);

      await SettingsLocalDataSource(store).set('WHcategories', 110);
      expect((await service.search('girl')).prismResults.map((wall) => wall.id), unorderedEquals(<String>['p1', 'p2']));
    });

    test('a failed search is not cached', () async {
      final repository = _FakeWallhavenRepository(Result.error<List<WallhavenWallpaper>>(const ServerFailure('503')));
      final service = _service(
        wallhaven: repository.result,
        pexels: Result.error<List<PexelsWallpaper>>(const ServerFailure('500')),
        wallhavenRepository: repository,
      );

      await expectLater(service.search('mountain'), throwsA(isA<WallpaperSearchException>()));
      await expectLater(service.search('mountain'), throwsA(isA<WallpaperSearchException>()));

      expect(repository.calls, 2);
    });
  });

  test('search returns Wallhaven results when Wallhaven answers', () async {
    final service = _service(wallhaven: Result.success(<WallhavenWallpaper>[_wallhaven('a')]));

    final page = await service.search('mountain');

    expect(page.provider, SearchProviderValue.wallhaven);
    expect(page.results.map((wallpaper) => wallpaper.id), <String>['a']);
  });

  test('search falls back to Pexels when Wallhaven fails', () async {
    final service = _service(
      wallhaven: Result.error<List<WallhavenWallpaper>>(const ServerFailure('503')),
      pexels: Result.success(<PexelsWallpaper>[_pexels('p1')]),
    );

    final page = await service.search('mountain');

    expect(page.provider, SearchProviderValue.pexels);
    expect(page.results.map((wallpaper) => wallpaper.id), <String>['p1']);
  });

  test('search throws when both providers fail', () async {
    final service = _service(
      wallhaven: Result.error<List<WallhavenWallpaper>>(const ServerFailure('503')),
      pexels: Result.error<List<PexelsWallpaper>>(const ServerFailure('500')),
    );

    await expectLater(service.search('mountain'), throwsA(isA<WallpaperSearchException>()));
  });

  test('both provider failures fall back to matching public metadata with an explicit local scope', () async {
    final Directory directory = await Directory.systemTemp.createTemp('local-wallpaper-search-');
    addTearDown(() => directory.delete(recursive: true));
    final OfflineWallpaperCatalog catalog = OfflineWallpaperCatalog(
      store: DurableJsonStore('catalog', directory: directory),
    );
    await catalog.remember(const <FeedItemEntity>[
      PrismFeedItem(
        id: 'local-wall',
        wallpaper: PrismWallpaper(
          core: WallpaperCore(
            id: 'local-wall',
            source: WallpaperSource.prism,
            fullUrl: 'https://example.test/wall.jpg',
            thumbnailUrl: 'https://example.test/thumb.jpg',
          ),
          title: 'Moss forest',
          tags: <String>['green'],
        ),
      ),
    ]);
    final service = WallpaperSearchService(
      _FakeWallhavenRepository(Result.error<List<WallhavenWallpaper>>(const ServerFailure('offline'))),
      _FakePexelsRepository(Result.error<List<PexelsWallpaper>>(const ServerFailure('offline'))),
      SettingsLocalDataSource(InMemoryLocalStore()),
      PrismWallSearch(
        FakeFirestoreClient()..queryError = StateError('offline'),
        FakeUserBlockRepository.pending()..completeInitial(<String>{}),
      ),
      catalog,
    );

    final page = await service.search('moss');

    expect(page.isLocal, isTrue);
    expect(page.results.map((item) => item.id), <String>['local-wall']);
  });

  test('search returns a Prism-only page when both providers fail but Prism has matches', () async {
    final firestore = FakeFirestoreClient(
      onQuery: (spec) => spec.sourceTag == 'PrismWallSearch.terms'
          ? <FakeDocRow>[(id: 'd1', data: _prismDoc('w1'))]
          : const <FakeDocRow>[],
    );
    final service = _service(
      wallhaven: Result.error<List<WallhavenWallpaper>>(const ServerFailure('503')),
      pexels: Result.error<List<PexelsWallpaper>>(const ServerFailure('500')),
      firestore: firestore,
    );

    final page = await service.search('mountain');

    expect(page.provider, SearchProviderValue.prism);
    expect(page.results, isEmpty);
    expect(page.prismResults.map((wall) => wall.id), <String>['w1']);
  });

  test('search returns an empty list when Wallhaven finds nothing', () async {
    final service = _service(wallhaven: Result.success(<WallhavenWallpaper>[]));

    final page = await service.search('zzzz');

    expect(page.provider, SearchProviderValue.wallhaven);
    expect(page.results, isEmpty);
  });

  test('fetchPage throws when the provider fails, so the grid can report the failure', () async {
    final service = _service(wallhaven: Result.error<List<WallhavenWallpaper>>(const ServerFailure('503')));

    await expectLater(service.fetchPage(SearchProviderValue.wallhaven, 'mountain', refresh: false), throwsException);
  });

  test('fetchPage sends the saved Wallhaven filters and defaults them to 100', () async {
    final repository = _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[]));
    final store = InMemoryLocalStore();
    final service = _service(wallhaven: repository.result, store: store, wallhavenRepository: repository);

    await service.fetchPage(SearchProviderValue.wallhaven, 'mountain', refresh: true);
    expect((repository.lastCategories, repository.lastPurity, repository.lastRefresh), (100, 100, true));

    await SettingsLocalDataSource(store).set('WHcategories', 111);
    await SettingsLocalDataSource(store).set('WHpurity', 110);
    await service.fetchPage(SearchProviderValue.wallhaven, 'mountain', refresh: false);
    expect((repository.lastCategories, repository.lastPurity, repository.lastRefresh), (111, 110, false));
  });

  test('search keys the page cursor by query, so a query cannot reuse a category cursor', () async {
    final repository = _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[]));
    final service = _service(wallhaven: repository.result, wallhavenRepository: repository);

    await service.search('nature');

    expect(repository.lastPaginationKey, 'search:nature');
  });

  test('filters map to Wallhaven query params', () async {
    final repository = _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[]));
    final service = _service(wallhaven: repository.result, wallhavenRepository: repository);

    await service.search('nature');
    expect((repository.lastPortraitOnly, repository.lastMinResolution, repository.lastSorting), (true, null, null));

    await service.search(
      'nature',
      filters: const SearchFilters(portraitOnly: false, minResolution: '1440x2560', sort: SearchSort.latest),
    );
    expect(
      (repository.lastPortraitOnly, repository.lastMinResolution, repository.lastSorting),
      (false, '1440x2560', 'date_added'),
    );

    await service.fetchPage(
      SearchProviderValue.wallhaven,
      'nature',
      refresh: true,
      filters: const SearchFilters(sort: SearchSort.toplist),
    );
    expect(repository.lastSorting, 'toplist');
  });

  test('Pexels gets the portrait flag and a client-side minimum resolution', () async {
    final pexels = _FakePexelsRepository(
      Result.success(<PexelsWallpaper>[
        _pexels('big', resolution: '2160x3840'),
        _pexels('small', resolution: '720x1280'),
        _pexels('unknown'),
      ]),
    );
    final service = _service(wallhaven: Result.success(<WallhavenWallpaper>[]), pexelsRepository: pexels);

    final results = await service.fetchPage(
      SearchProviderValue.pexels,
      'nature',
      refresh: true,
      filters: const SearchFilters(minResolution: '1080x1920'),
    );

    expect(results.map((wall) => wall.id), <String>['big', 'unknown']);
    expect(pexels.lastPortraitOnly, isTrue);
    expect(pexels.lastPaginationKey, 'search:nature');
  });

  group('colour', () {
    test('Wallhaven gets the palette hex, and the page cursor is keyed by colour', () async {
      final repository = _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[]));
      final service = _service(wallhaven: repository.result, wallhavenRepository: repository);

      await service.search('nature', filters: SearchFilters(color: paletteColorById('blue')));

      expect(repository.lastColors, '0066cc');
      expect(repository.lastPaginationKey, 'search:nature:color:blue');
    });

    test('Wallhaven gets no colour without a colour filter', () async {
      final repository = _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[]));
      final service = _service(wallhaven: repository.result, wallhavenRepository: repository);

      await service.search('nature');

      expect(repository.lastColors, isNull);
    });

    test('Pexels gets the Pexels colour name', () async {
      final pexels = _FakePexelsRepository(Result.success(<PexelsWallpaper>[]));
      final service = _service(
        wallhaven: Result.error<List<WallhavenWallpaper>>(const ServerFailure('503')),
        pexelsRepository: pexels,
      );

      await service.search('nature', filters: SearchFilters(color: paletteColorById('purple')));

      expect(pexels.lastColor, 'violet');
      expect(pexels.lastPaginationKey, 'search:nature:color:purple');
    });

    test('a colour with an empty query searches Wallhaven with no query', () async {
      final repository = _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[_wallhaven('a')]));
      final service = _service(wallhaven: repository.result, wallhavenRepository: repository);

      final page = await service.search('', filters: SearchFilters(color: paletteColorById('red')));

      expect(page.provider, SearchProviderValue.wallhaven);
      expect(repository.lastCategoryName, '');
      expect(repository.lastColors, 'cc0000');
      expect(page.results.map((wall) => wall.id), <String>['a']);
    });

    test('a colour-only search skips Pexels when Wallhaven fails', () async {
      final pexels = _FakePexelsRepository(Result.success(<PexelsWallpaper>[_pexels('p1')]));
      final service = _service(
        wallhaven: Result.error<List<WallhavenWallpaper>>(const ServerFailure('503')),
        pexelsRepository: pexels,
      );

      await expectLater(
        service.search('', filters: SearchFilters(color: paletteColorById('red'))),
        throwsA(isA<WallpaperSearchException>()),
      );
      expect(pexels.calls, 0);
    });

    test('a colour-only search falls back to Prism walls when Wallhaven fails', () async {
      final firestore = FakeFirestoreClient(
        onQuery: (spec) => spec.sourceTag == 'PrismWallSearch.color'
            ? <FakeDocRow>[
                (id: 'd1', data: _prismDoc('w1', colors: ['red'])),
              ]
            : const <FakeDocRow>[],
      );
      final service = _service(
        wallhaven: Result.error<List<WallhavenWallpaper>>(const ServerFailure('503')),
        firestore: firestore,
      );

      final page = await service.search('', filters: SearchFilters(color: paletteColorById('red')));

      expect(page.provider, SearchProviderValue.prism);
      expect(page.prismResults.map((wall) => wall.id), <String>['w1']);
    });

    test('an empty query without a colour does not search Prism', () async {
      final firestore = FakeFirestoreClient();
      final service = _service(wallhaven: Result.success(<WallhavenWallpaper>[]), firestore: firestore);

      await service.search('');

      expect(firestore.querySpecs, isEmpty);
    });

    test('the Prism catalogue gets where colors array-contains the id', () async {
      final firestore = FakeFirestoreClient();
      final service = _service(wallhaven: Result.success(<WallhavenWallpaper>[]), firestore: firestore);

      await service.search('', filters: SearchFilters(color: paletteColorById('teal')));

      final spec = firestore.querySpecs.single;
      expect(spec.sourceTag, 'PrismWallSearch.color');
      expect(spec.filters.map((f) => (f.field, f.op, f.value)), <(String, FirestoreFilterOp, Object?)>[
        ('review', FirestoreFilterOp.isEqualTo, true),
        ('colors', FirestoreFilterOp.arrayContains, 'teal'),
      ]);
    });

    test('with a query the Prism matches are kept only when they have the colour', () async {
      final firestore = FakeFirestoreClient(
        onQuery: (spec) => spec.sourceTag == 'PrismWallSearch.terms'
            ? <FakeDocRow>[
                (id: 'd1', data: _prismDoc('blue1', colors: ['blue', 'white'])),
                (id: 'd2', data: _prismDoc('red1', colors: ['red'])),
                (id: 'd3', data: _prismDoc('none')),
              ]
            : const <FakeDocRow>[],
      );
      final service = _service(wallhaven: Result.success(<WallhavenWallpaper>[]), firestore: firestore);

      final page = await service.search('nature', filters: SearchFilters(color: paletteColorById('blue')));

      expect(page.prismResults.map((wall) => wall.id), <String>['blue1']);
      expect(firestore.querySpecs.every((spec) => spec.filters.every((f) => f.field != 'colors')), isTrue);
    });
  });

  group('depth', () {
    const SearchFilters depthOnly = SearchFilters(depthOnly: true);

    PrismFeedItem savedPrism(String id, WallDepthTier? tier) => PrismFeedItem(
      id: id,
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: id,
          source: WallpaperSource.prism,
          fullUrl: 'https://prism/$id.jpg',
          thumbnailUrl: 'https://prism/$id-thumb.jpg',
        ),
        title: 'Moss forest $id',
        depthTier: tier,
      ),
    );

    Future<WallpaperSearchService> serviceWithSaved(
      List<FeedItemEntity> saved, {
      required FakeFirestoreClient firestore,
      required _FakeWallhavenRepository wallhaven,
      required _FakePexelsRepository pexels,
    }) async {
      final Directory directory = await Directory.systemTemp.createTemp('depth-search-catalog-');
      addTearDown(() => directory.delete(recursive: true));
      final OfflineWallpaperCatalog catalog = OfflineWallpaperCatalog(
        store: DurableJsonStore('catalog', directory: directory),
      );
      await catalog.remember(saved);
      return WallpaperSearchService(
        wallhaven,
        pexels,
        SettingsLocalDataSource(InMemoryLocalStore()),
        PrismWallSearch(firestore, FakeUserBlockRepository.pending()..completeInitial(<String>{})),
        catalog,
      );
    }

    test('lists only Prism auto and menu walls and never asks Wallhaven or Pexels', () async {
      final wallhaven = _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[_wallhaven('wh')]));
      final pexels = _FakePexelsRepository(Result.success(<PexelsWallpaper>[_pexels('px')]));
      final firestore = FakeFirestoreClient(
        onQuery: (spec) => <FakeDocRow>[
          (id: 'd1', data: _prismDoc('auto1', depthTier: 'auto')),
          (id: 'd2', data: _prismDoc('none1', depthTier: 'none')),
          (id: 'd3', data: _prismDoc('menu1', depthTier: 'menu')),
          (id: 'd4', data: _prismDoc('unchecked')),
        ],
      );
      final service = _service(
        wallhaven: wallhaven.result,
        wallhavenRepository: wallhaven,
        pexelsRepository: pexels,
        firestore: firestore,
      );

      final page = await service.search('', filters: depthOnly);

      expect(page.provider, SearchProviderValue.prism);
      expect(page.results.map((wall) => wall.id), <String>['auto1', 'menu1']);
      expect(page.prismResults, isEmpty);
      expect(page.isLocal, isFalse);
      expect((wallhaven.calls, pexels.calls), (0, 0));
      expect(firestore.querySpecs.single.sourceTag, 'PrismWallSearch.depth');
    });

    test('a depth browse asks Prism search for 48 walls and a text query keeps 12', () async {
      final firestore = FakeFirestoreClient(
        onQuery: (spec) => <FakeDocRow>[
          for (int i = 0; i < spec.limit!; i++) (id: 'd$i', data: _prismDoc('w$i', depthTier: 'auto')),
        ],
      );
      final service = _service(wallhaven: Result.success(<WallhavenWallpaper>[]), firestore: firestore);

      final browse = await service.search('', filters: depthOnly);

      expect(firestore.querySpecs.single.limit, 48);
      expect(browse.results, hasLength(48));

      final text = await service.search('moss', filters: depthOnly);

      expect(text.results, hasLength(12));
    });

    test('an empty page is a page, not an error, when nothing has a depth tier', () async {
      final service = _service(
        wallhaven: Result.error<List<WallhavenWallpaper>>(const ServerFailure('503')),
        pexels: Result.error<List<PexelsWallpaper>>(const ServerFailure('500')),
      );

      final page = await service.search('', filters: depthOnly);

      expect(page.results, isEmpty);
      expect(page.prismResults, isEmpty);
    });

    test('saved walls fill in when Prism has no match, and only auto and menu Prism walls stay', () async {
      final wallhaven = _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[_wallhaven('wh')]));
      final pexels = _FakePexelsRepository(Result.success(<PexelsWallpaper>[]));
      final service = await serviceWithSaved(
        <FeedItemEntity>[
          savedPrism('saved-auto', WallDepthTier.auto),
          savedPrism('saved-menu', WallDepthTier.menu),
          savedPrism('saved-none', WallDepthTier.none),
          savedPrism('saved-unchecked', null),
          const WallhavenFeedItem(
            id: 'moss-wallhaven',
            wallpaper: WallhavenWallpaper(
              core: WallpaperCore(
                id: 'moss-wallhaven',
                source: WallpaperSource.wallhaven,
                fullUrl: 'https://w/moss.jpg',
                thumbnailUrl: 't',
              ),
              tags: <String>['moss'],
            ),
          ),
        ],
        firestore: FakeFirestoreClient()..queryError = StateError('offline'),
        wallhaven: wallhaven,
        pexels: pexels,
      );

      final page = await service.search('moss', filters: depthOnly);

      expect(page.results.map((wall) => wall.id).toSet(), <String>{'saved-auto', 'saved-menu'});
      expect(page.isLocal, isTrue);
      expect(wallhaven.calls, 0);
    });

    test('Prism matches win over saved walls', () async {
      final firestore = FakeFirestoreClient(
        onQuery: (spec) => <FakeDocRow>[(id: 'd1', data: _prismDoc('live', depthTier: 'menu'))],
      );
      final service = await serviceWithSaved(
        <FeedItemEntity>[savedPrism('saved-auto', WallDepthTier.auto)],
        firestore: firestore,
        wallhaven: _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[])),
        pexels: _FakePexelsRepository(Result.success(<PexelsWallpaper>[])),
      );

      final page = await service.search('moss', filters: depthOnly);

      expect(page.results.map((wall) => wall.id), <String>['live']);
      expect(page.isLocal, isFalse);
    });

    test('without the filter a depth tier changes nothing', () async {
      final service = _service(wallhaven: Result.success(<WallhavenWallpaper>[_wallhaven('a')]));

      final page = await service.search('mountain');

      expect(page.provider, SearchProviderValue.wallhaven);
      expect(page.results.map((wall) => wall.id), <String>['a']);
    });
  });

  group('prismResults', () {
    test('holds Prism walls that match the search terms, filtered by resolution', () async {
      final firestore = FakeFirestoreClient(
        onQuery: (spec) => <FakeDocRow>[
          (id: 'd1', data: _prismDoc('w1')),
          (id: 'd2', data: _prismDoc('w2', resolution: '640x480')),
          (id: 'd3', data: _prismDoc('w3')),
        ],
      );
      final service = _service(wallhaven: Result.success(<WallhavenWallpaper>[_wallhaven('a')]), firestore: firestore);

      final page = await service.search('Nature');

      expect(page.prismResults.map((wall) => wall.id), <String>['w1', 'w3']);
      final spec = firestore.querySpecs.single;
      expect(spec.sourceTag, 'PrismWallSearch.terms');
      expect(spec.filters.map((f) => (f.field, f.op)), <(String, FirestoreFilterOp)>[
        ('review', FirestoreFilterOp.isEqualTo),
        ('searchTerms', FirestoreFilterOp.arrayContainsAny),
      ]);
      expect(spec.filters.last.value, <String>['nature']);
    });

    test('is empty when the Prism query fails, for example because the index is not deployed', () async {
      final firestore = FakeFirestoreClient()..queryError = Exception('failed-precondition: needs an index');
      final service = _service(wallhaven: Result.success(<WallhavenWallpaper>[_wallhaven('a')]), firestore: firestore);

      final page = await service.search('nature');

      expect(page.results.map((wall) => wall.id), <String>['a']);
      expect(page.prismResults, isEmpty);
    });

    test('hides walls from blocked creators', () async {
      final firestore = FakeFirestoreClient(
        onQuery: (spec) => <FakeDocRow>[(id: 'd1', data: _prismDoc('w1', creatorUid: 'blocked-id'))],
      );
      final service = WallpaperSearchService(
        _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[])),
        _FakePexelsRepository(Result.success(<PexelsWallpaper>[])),
        SettingsLocalDataSource(InMemoryLocalStore()),
        PrismWallSearch(firestore, FakeUserBlockRepository.pending()..completeInitial(<String>{'blocked-id'})),
      );

      expect((await service.search('nature')).prismResults, isEmpty);
    });

    test('skips the Prism query for a one-letter query', () async {
      final firestore = FakeFirestoreClient();
      final service = _service(wallhaven: Result.success(<WallhavenWallpaper>[]), firestore: firestore);

      await service.search('a');

      expect(firestore.querySpecs, isEmpty);
    });
  });
}
