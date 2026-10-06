import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
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
  _FakeWallhavenRepository(this.result);

  final Result<List<WallhavenWallpaper>> result;
  int? lastCategories;
  int? lastPurity;
  bool? lastRefresh;
  bool? lastPortraitOnly;
  String? lastMinResolution;
  String? lastSorting;
  String? lastPaginationKey;

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
  }) async {
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

  @override
  Future<Result<List<PexelsWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int startPage = 1,
    String? paginationKey,
    bool portraitOnly = true,
  }) async {
    lastPortraitOnly = portraitOnly;
    lastPaginationKey = paginationKey;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

Map<String, dynamic> _prismDoc(String id, {String resolution = '1080x2400', String email = 'a@example.com'}) =>
    <String, dynamic>{
      'id': id,
      'wallpaper_url': 'https://prism/$id.jpg',
      'wallpaper_thumb': 'https://prism/$id-thumb.jpg',
      'wallpaper_provider': 'prism',
      'resolution': resolution,
      'email': email,
      'review': true,
    };

void main() {
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
