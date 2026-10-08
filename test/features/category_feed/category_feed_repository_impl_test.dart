import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/category_feed/data/repositories/category_feed_repository_impl.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_feed_cache_local_data_source.dart';
import '../../support/in_memory_local_store.dart';

class _MockPrism extends Mock implements PrismWallpaperRepository {}

class _MockWallhaven extends Mock implements WallhavenWallpaperRepository {}

class _MockPexels extends Mock implements PexelsWallpaperRepository {}

const CategoryEntity _cyberpunk = CategoryEntity(
  name: 'Cyberpunk',
  source: WallpaperSource.wallhaven,
  searchType: CategorySearchType.search,
  image: '',
  image2: '',
);

WallhavenWallpaper _wall(String id) => WallhavenWallpaper(
  core: WallpaperCore(id: id, source: WallpaperSource.wallhaven, fullUrl: 'https://w/$id.jpg', thumbnailUrl: 't'),
);

void main() {
  late _MockWallhaven wallhaven;
  late FakeFeedCacheLocalDataSource cache;
  late InMemoryLocalStore store;
  late CategoryFeedRepositoryImpl repository;
  bool offline = false;

  setUp(() {
    wallhaven = _MockWallhaven();
    cache = FakeFeedCacheLocalDataSource();
    store = InMemoryLocalStore();
    offline = false;
    when(() => wallhaven.hasMoreForCategory(any(), paginationKey: any(named: 'paginationKey'))).thenReturn(true);
    when(
      () => wallhaven.fetchFeed(
        categoryName: any(named: 'categoryName'),
        refresh: any(named: 'refresh'),
        categories: any(named: 'categories'),
        purity: any(named: 'purity'),
      ),
    ).thenAnswer(
      (_) async => offline
          ? Result.error<List<WallhavenWallpaper>>(const ServerFailure('503'))
          : Result.success(<WallhavenWallpaper>[_wall('a')]),
    );
    repository = CategoryFeedRepositoryImpl(
      SettingsLocalDataSource(store),
      cache,
      _MockPrism(),
      wallhaven,
      _MockPexels(),
    );
  });

  test('only a refresh writes the snapshot', () async {
    await repository.fetchCategoryFeed(category: _cyberpunk, refresh: false);
    expect(cache.snapshots, isEmpty);

    await repository.fetchCategoryFeed(category: _cyberpunk, refresh: true);
    expect(cache.snapshots, hasLength(1));
  });

  test('a failed fetch-more is an error even when a snapshot exists', () async {
    await repository.fetchCategoryFeed(category: _cyberpunk, refresh: true);
    offline = true;

    final more = await repository.fetchCategoryFeed(category: _cyberpunk, refresh: false);
    final refreshed = await repository.fetchCategoryFeed(category: _cyberpunk, refresh: true);

    expect(more.isFailure, isTrue);
    expect(refreshed.data!.items.map((item) => item.id), <String>['a']);
  });

  test('the snapshot scope changes with the Wallhaven categories and purity filters', () async {
    await repository.fetchCategoryFeed(category: _cyberpunk, refresh: true);
    await SettingsLocalDataSource(store).set('WHcategories', 110);
    await repository.fetchCategoryFeed(category: _cyberpunk, refresh: true);
    await SettingsLocalDataSource(store).set('WHpurity', 110);
    await repository.fetchCategoryFeed(category: _cyberpunk, refresh: true);

    expect(cache.snapshots.keys, hasLength(3));
    offline = true;
    await SettingsLocalDataSource(store).set('WHcategories', 111);
    expect(
      (await repository.fetchCategoryFeed(category: _cyberpunk, refresh: true)).isFailure,
      isTrue,
      reason: 'a snapshot saved under other filters must not be served',
    );
  });
}
