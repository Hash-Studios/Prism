// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/favourite_walls/data/favourite_wall_doc_mapper.dart';
import 'package:Prism/features/favourite_walls/data/repositories/favourite_walls_repository_impl.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_firestore_client.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../support/fav_fixtures.dart';
import '../../support/guest_store_fixture.dart';

class _MemoryStore extends DurableJsonStore {
  _MemoryStore() : super('hydration');
  final records = <String, Map<String, Object?>>{};

  @override
  Future<Map<String, Object?>?> read(String key) async => records[key];
  @override
  Future<void> write(String key, Map<String, Object?> value) async => records[key] = value;
  @override
  Future<Map<String, Map<String, Object?>>> readAll() async => Map.of(records);
  @override
  Future<void> delete(String key) async => records.remove(key);
}

class _Firestore extends FakeFirestoreClient {
  List<FavouriteWallEntity> walls = <FavouriteWallEntity>[];
  bool offline = false;

  @override
  Stream<({List<T> items, bool isFromCache})> watchQueryWithMetadata<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic>, String) map,
  ) async* {
    if (offline) throw StateError('offline');
    yield (items: walls.map((wall) => map(favouriteWallToDoc(wall), wall.id)).toList(), isFromCache: false);
  }
}

class _Canonical extends Fake implements PrismWallpaperRepository {
  final calls = <String>[];
  Future<Result<PrismWallpaper?>> Function(String) lookup = (_) async => Result.success(null);

  @override
  Future<Result<PrismWallpaper?>> fetchCanonicalById(String id) {
    calls.add(id);
    return lookup(id);
  }
}

PrismWallpaper _current(String id, String collection) => PrismWallpaper(
  core: WallpaperCore(
    id: id,
    source: WallpaperSource.prism,
    fullUrl: 'https://example.com/current.jpg',
    thumbnailUrl: 'https://example.com/current-thumb.jpg',
    authorName: 'Current creator',
    category: 'Current category',
  ),
  collections: <String>[collection],
  firestoreDocumentId: 'canonical-doc',
);

void main() {
  late _Firestore firestore;
  late _Canonical canonical;
  late FavoritesLocalDataSource local;

  setUp(() {
    firestore = _Firestore();
    canonical = _Canonical();
    local = FavoritesLocalDataSource(InMemoryLocalStore(), durableStore: _MemoryStore());
  });

  test('every fetch hydrates canonical metadata while preserving favourite time and identity', () async {
    final savedAt = DateTime.utc(2025, 3, 4);
    firestore.walls = <FavouriteWallEntity>[prismFav('remote', favouritedAt: savedAt)];
    var collection = 'premium';
    canonical.lookup = (id) async => Result.success(_current(id, collection));
    final repository = FavouriteWallsRepositoryImpl(firestore, local, unusedGuestStore(), canonical);

    final first = (await repository.fetchFavourites(userId: 'user')).data!.single as PrismFavouriteWall;
    expect(first.id, 'remote');
    expect(first.favouritedAt, savedAt);
    expect(first.syncStatus, FavouriteSyncStatus.synced);
    expect(first.wallpaper.collections, <String>['premium']);
    expect(first.wallpaper.firestoreDocumentId, 'canonical-doc');
    expect(first.authorName, 'Current creator');
    expect(first.category, 'Current category');
    collection = 'free';
    final second = (await repository.fetchFavourites(userId: 'user')).data!.single as PrismFavouriteWall;
    expect(second.wallpaper.collections, <String>['free']);
    expect(canonical.calls, <String>['remote', 'remote']);
    expect(firestore.writes, isEmpty);
  });

  test('missing, failed and throwing canonical reads keep saved membership and thumbnail', () async {
    firestore.walls = <FavouriteWallEntity>[prismFav('missing'), prismFav('failure'), prismFav('throws')];
    canonical.lookup = (id) async {
      if (id == 'throws') throw StateError('offline');
      if (id == 'failure') return Result.error(const ServerFailure('offline'));
      return Result.success(null);
    };
    final repository = FavouriteWallsRepositoryImpl(firestore, local, unusedGuestStore(), canonical);
    final result = await repository.fetchFavourites(userId: 'user');
    expect(result.data!.map((wall) => wall.id), unorderedEquals(<String>['missing', 'failure', 'throws']));
    for (final wall in result.data!) {
      expect(wall.thumbnailUrl, 'https://example.com/${wall.id}-thumb.jpg');
    }
    expect(await local.readWallSnapshot('user'), hasLength(3));
    expect(firestore.writes, isEmpty);
  });

  test('an existing collection becoming premium changes classification after config refresh', () async {
    firestore.walls = <FavouriteWallEntity>[prismFav('remote')];
    canonical.lookup = (id) async => Result.success(_current(id, 'collection'));
    final repository = FavouriteWallsRepositoryImpl(firestore, local, unusedGuestStore(), canonical);
    final favourite = (await repository.fetchFavourites(userId: 'user')).data!.single;

    expect(isPremiumFeedItem(favourite.toFeedItem(), <String>[]), isFalse);
    expect(isPremiumFeedItem(favourite.toFeedItem(), <String>['collection']), isTrue);
  });

  test('a protected canonical wall without a public original remains a favourite preview', () async {
    firestore.walls = <FavouriteWallEntity>[prismFav('remote')];
    canonical.lookup = (id) async => Result.success(
      PrismWallpaper(
        core: WallpaperCore(
          id: id,
          source: WallpaperSource.prism,
          fullUrl: '',
          thumbnailUrl: 'https://example.com/protected-thumb.jpg',
        ),
        collections: <String>['premium'],
      ),
    );
    final repository = FavouriteWallsRepositoryImpl(firestore, local, unusedGuestStore(), canonical);
    final wall = (await repository.fetchFavourites(userId: 'user')).data!.single;

    expect(wall.id, 'remote');
    expect(wall.fullUrl, isEmpty);
    expect(wall.thumbnailUrl, 'https://example.com/protected-thumb.jpg');
    expect(isPremiumFeedItem(wall.toFeedItem(), <String>['premium']), isTrue);
  });

  test('guest Prism favourites hydrate but starters and external sources do not', () async {
    final guest = memoryGuestStore();
    for (final wall in <FavouriteWallEntity>[
      prismFav('remote'),
      prismFav('starter-sunset'),
      wallhavenFav('external'),
      pexelsFav('pexels'),
    ]) {
      await guest.put(wall.id, favouriteWallToDoc(wall));
    }
    canonical.lookup = (id) async => Result.success(_current(id, 'premium'));
    final repository = FavouriteWallsRepositoryImpl(firestore, local, guest, canonical);
    final result = await repository.fetchFavourites(userId: '');
    expect(result.data, hasLength(4));
    expect(canonical.calls, <String>['remote']);
    expect(
      result.data!.whereType<PrismFavouriteWall>().firstWhere((wall) => wall.id == 'remote').wallpaper.collections,
      <String>['premium'],
    );
    expect(firestore.writes, isEmpty);
  });

  test('pending additions hydrate after optimistic merge and preserve sync state', () async {
    final wall = prismFav('pending', favouritedAt: DateTime.utc(2025));
    await local.createFavouriteOperation('user', wall.id, desired: true, wall: favouriteWallToDoc(wall));
    canonical.lookup = (id) async => Result.success(_current(id, 'premium'));
    final repository = FavouriteWallsRepositoryImpl(firestore, local, unusedGuestStore(), canonical);
    final result = (await repository.fetchFavourites(userId: 'user')).data!.single as PrismFavouriteWall;
    expect(result.syncStatus, FavouriteSyncStatus.pending);
    expect(result.favouritedAt, wall.favouritedAt);
    expect(result.wallpaper.collections, <String>['premium']);
  });

  test('local fallback also hydrates without removing saved membership', () async {
    await local.saveWallSnapshot('user', <FavouriteWallEntity>[prismFav('cached')]);
    firestore.offline = true;
    canonical.lookup = (id) async => Result.success(_current(id, 'premium'));
    final repository = FavouriteWallsRepositoryImpl(firestore, local, unusedGuestStore(), canonical);
    final result = (await repository.fetchFavourites(userId: 'user')).data!.single as PrismFavouriteWall;
    expect(result.id, 'cached');
    expect(result.wallpaper.collections, <String>['premium']);
  });

  test('a pending removal is not restored by canonical hydration', () async {
    final wall = prismFav('removed');
    firestore.walls = <FavouriteWallEntity>[wall];
    await local.createFavouriteOperation('user', wall.id, desired: false, wall: favouriteWallToDoc(wall));
    canonical.lookup = (id) async => Result.success(_current(id, 'premium'));
    final repository = FavouriteWallsRepositoryImpl(firestore, local, unusedGuestStore(), canonical);
    expect((await repository.fetchFavourites(userId: 'user')).data, isEmpty);
    expect(canonical.calls, isEmpty);
  });

  test('offline hydration bounds concurrency and total wait for a large library', () {
    fakeAsync((async) {
      firestore.walls = List.generate(40, (index) => prismFav('wall-$index'));
      canonical.lookup = (_) => Completer<Result<PrismWallpaper?>>().future;
      final repository = FavouriteWallsRepositoryImpl(firestore, local, unusedGuestStore(), canonical);
      List<FavouriteWallEntity>? result;
      repository.fetchFavourites(userId: 'user').then((value) => result = value.data);
      async.flushMicrotasks();
      expect(canonical.calls, hasLength(4));
      expect(result, isNull);
      async.elapse(const Duration(seconds: 8));
      async.flushMicrotasks();
      expect(result, hasLength(40));
      expect(canonical.calls, hasLength(4));
    });
  });
}
