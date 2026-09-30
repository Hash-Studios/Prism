import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

class _FakeWallhavenRepository implements WallhavenWallpaperRepository {
  _FakeWallhavenRepository(this.result);

  final Result<List<WallhavenWallpaper>> result;
  int? lastCategories;
  int? lastPurity;
  bool? lastRefresh;

  @override
  Future<Result<List<WallhavenWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int categories = 100,
    int purity = 100,
  }) async {
    lastCategories = categories;
    lastPurity = purity;
    lastRefresh = refresh;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePexelsRepository implements PexelsWallpaperRepository {
  _FakePexelsRepository(this.result);

  final Result<List<PexelsWallpaper>> result;

  @override
  Future<Result<List<PexelsWallpaper>>> fetchFeed({required String categoryName, required bool refresh}) async =>
      result;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WallhavenWallpaper _wallhaven(String id) => WallhavenWallpaper(
  core: WallpaperCore(id: id, source: WallpaperSource.wallhaven, fullUrl: 'https://w/$id.jpg', thumbnailUrl: 't'),
);

PexelsWallpaper _pexels(String id) => PexelsWallpaper(
  core: WallpaperCore(id: id, source: WallpaperSource.pexels, fullUrl: 'https://p/$id.jpg', thumbnailUrl: 't'),
);

WallpaperSearchService _service({
  required Result<List<WallhavenWallpaper>> wallhaven,
  Result<List<PexelsWallpaper>>? pexels,
  InMemoryLocalStore? store,
  _FakeWallhavenRepository? wallhavenRepository,
}) {
  return WallpaperSearchService(
    wallhavenRepository ?? _FakeWallhavenRepository(wallhaven),
    _FakePexelsRepository(pexels ?? Result.success(<PexelsWallpaper>[])),
    SettingsLocalDataSource(store ?? InMemoryLocalStore()),
  );
}

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

  test('search returns an empty page when both providers fail', () async {
    final service = _service(
      wallhaven: Result.error<List<WallhavenWallpaper>>(const ServerFailure('503')),
      pexels: Result.error<List<PexelsWallpaper>>(const ServerFailure('500')),
    );

    final page = await service.search('mountain');

    expect(page.provider, SearchProviderValue.pexels);
    expect(page.results, isEmpty);
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
}
