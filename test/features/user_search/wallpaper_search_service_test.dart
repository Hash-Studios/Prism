import 'dart:io';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/data/prism_wall_search.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:flutter_test/flutter_test.dart';

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
  String email = 'a@example.com',
  List<String> colors = const <String>[],
}) => <String, dynamic>{
  'id': id,
  'wallpaper_url': 'https://prism/$id.jpg',
  'wallpaper_thumb': 'https://prism/$id-thumb.jpg',
  'wallpaper_provider': 'prism',
  'resolution': resolution,
  'email': email,
  'review': true,
  'colors': colors,
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
      onQuery: (spec) => spec.sourceTag == 'PrismWallSearch.tags'
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
      onQuery: (spec) => spec.sourceTag == 'PrismWallSearch.tags'
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
        onQuery: (spec) => spec.sourceTag == 'PrismWallSearch.tags'
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

  group('prismResults', () {
    test('holds Prism walls that match by tag or category, deduplicated and filtered by resolution', () async {
      final firestore = FakeFirestoreClient(
        onQuery: (spec) => switch (spec.sourceTag) {
          'PrismWallSearch.tags' => <FakeDocRow>[
            (id: 'd1', data: _prismDoc('w1')),
            (id: 'd2', data: _prismDoc('w2', resolution: '640x480')),
          ],
          'PrismWallSearch.category' => <FakeDocRow>[
            (id: 'd1', data: _prismDoc('w1')),
            (id: 'd3', data: _prismDoc('w3')),
          ],
          _ => const <FakeDocRow>[],
        },
      );
      final service = _service(wallhaven: Result.success(<WallhavenWallpaper>[_wallhaven('a')]), firestore: firestore);

      final page = await service.search('Nature');

      expect(page.prismResults.map((wall) => wall.id), <String>['w1', 'w3']);
      final tagSpec = firestore.querySpecs.firstWhere((spec) => spec.sourceTag == 'PrismWallSearch.tags');
      expect(tagSpec.filters.map((f) => f.field), <String>['review', 'tags']);
      expect(tagSpec.filters.last.op, FirestoreFilterOp.arrayContainsAny);
      expect(tagSpec.filters.last.value, containsAll(<String>['nature', 'Nature']));
      final categorySpec = firestore.querySpecs.firstWhere((spec) => spec.sourceTag == 'PrismWallSearch.category');
      expect(categorySpec.filters.last.value, contains('Nature'));
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
        onQuery: (spec) => <FakeDocRow>[(id: 'd1', data: _prismDoc('w1', email: 'blocked@example.com'))],
      );
      final service = WallpaperSearchService(
        _FakeWallhavenRepository(Result.success(<WallhavenWallpaper>[])),
        _FakePexelsRepository(Result.success(<PexelsWallpaper>[])),
        SettingsLocalDataSource(InMemoryLocalStore()),
        PrismWallSearch(firestore, FakeUserBlockRepository.pending()..completeInitial(<String>{'blocked@example.com'})),
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
