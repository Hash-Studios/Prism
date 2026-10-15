import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/category_feed/data/repositories/category_feed_repository_impl.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
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

  group('Prism-first categories', () {
    late _MockPrism prism;
    const CategoryEntity nature = CategoryEntity(
      name: 'Nature',
      source: WallpaperSource.wallhaven,
      searchType: CategorySearchType.search,
      image: '',
      image2: '',
      hasPrismWalls: true,
    );

    PrismWallpaper prismWall(String id, {String? url}) => PrismWallpaper(
      core: WallpaperCore(
        id: id,
        source: WallpaperSource.prism,
        fullUrl: url ?? 'https://prism.test/$id.jpg',
        thumbnailUrl: 't',
      ),
    );

    setUp(() {
      prism = _MockPrism();
      repository = CategoryFeedRepositoryImpl(SettingsLocalDataSource(store), cache, prism, wallhaven, _MockPexels());
    });

    test('the first page starts with Prism walls, then the provider walls', () async {
      when(
        () => prism.fetchByCategory('Nature'),
      ).thenAnswer((_) async => Result.success(<PrismWallpaper>[prismWall('p1'), prismWall('p2')]));

      final result = await repository.fetchCategoryFeed(category: nature, refresh: true);

      expect(result.data!.items.map((item) => item.id), <String>['p1', 'p2', 'a']);
      expect(result.data!.items.take(2).every((item) => item is PrismFeedItem), isTrue);
      expect(result.data!.hasMore, isTrue);
    });

    test('a wall that is in both lists shows once, in its Prism place', () async {
      when(
        () => prism.fetchByCategory('Nature'),
      ).thenAnswer((_) async => Result.success(<PrismWallpaper>[prismWall('p1', url: 'https://w/A.jpg')]));

      final result = await repository.fetchCategoryFeed(category: nature, refresh: true);

      expect(result.data!.items.map((item) => item.id), <String>['p1']);
    });

    test('page 2 and later come from the provider only', () async {
      final result = await repository.fetchCategoryFeed(category: nature, refresh: false);

      expect(result.data!.items.map((item) => item.id), <String>['a']);
      verifyNever(
        () => prism.fetchByCategory(
          any(),
          startAfterDocId: any(named: 'startAfterDocId'),
          limit: any(named: 'limit'),
        ),
      );
    });

    test('a category without Prism walls never asks Prism', () async {
      await repository.fetchCategoryFeed(category: _cyberpunk, refresh: true);

      verifyNever(
        () => prism.fetchByCategory(
          any(),
          startAfterDocId: any(named: 'startAfterDocId'),
          limit: any(named: 'limit'),
        ),
      );
    });

    test('a Prism failure never fails the feed', () async {
      when(() => prism.fetchByCategory('Nature')).thenAnswer((_) async => Result.error(const ServerFailure('x')));

      final result = await repository.fetchCategoryFeed(category: nature, refresh: true);

      expect(result.data!.items.map((item) => item.id), <String>['a']);
    });

    test('the snapshot keeps the Prism walls, so an offline start shows them first', () async {
      when(
        () => prism.fetchByCategory('Nature'),
      ).thenAnswer((_) async => Result.success(<PrismWallpaper>[prismWall('p1')]));
      await repository.fetchCategoryFeed(category: nature, refresh: true);
      offline = true;

      final cached = await repository.fetchCategoryFeed(category: nature, refresh: true);

      expect(cached.data!.items.map((item) => item.id), <String>['p1', 'a']);
    });

    test('getCategories marks the classifier names and adds an AMOLED tile', () async {
      final categories = (await repository.getCategories()).data!;

      expect(categories.firstWhere((category) => category.name == 'Nature').hasPrismWalls, isTrue);
      expect(categories.firstWhere((category) => category.name == 'Forest').hasPrismWalls, isFalse);
      expect(categories.where((category) => category.hasPrismWalls), hasLength(18));
      final amoled = categories.singleWhere((category) => category.name == 'AMOLED');
      expect(amoled.source, WallpaperSource.wallhaven);
      expect(amoled.image, startsWith('https://images.pexels.com/photos/'));
    });
  });
}
