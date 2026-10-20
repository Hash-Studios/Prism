import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/features/favourite_walls/data/repositories/favourite_walls_repository_impl.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/prism_feed/data/repositories/prism_wallpaper_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_firestore_client.dart';
import '../../../../support/fake_user_block_repository.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../support/guest_store_fixture.dart';

class _MemoryDurableStore extends DurableJsonStore {
  _MemoryDurableStore() : super('canonical_refresh_test');

  final Map<String, Map<String, Object?>> _records = <String, Map<String, Object?>>{};

  @override
  Future<Map<String, Object?>?> read(String key) async => _records[key];

  @override
  Future<Map<String, Map<String, Object?>>> readAll() async => Map<String, Map<String, Object?>>.of(_records);

  @override
  Future<void> write(String key, Map<String, Object?> value) async => _records[key] = value;

  @override
  Future<void> delete(String key) async => _records.remove(key);
}

class _FavouriteAndCanonicalFirestore extends FakeFirestoreClient {
  _FavouriteAndCanonicalFirestore()
    : super(
        onQuery: (spec) => switch (spec.collection) {
          'usersv2/user-1/images' => <FakeDocRow>[
            (
              id: 'wall-1',
              data: <String, dynamic>{
                'id': 'wall-1',
                'provider': 'prism',
                'url': 'https://example.com/saved.jpg',
                'thumb': 'https://example.com/saved-thumb.jpg',
                'collections': <String>['free'],
              },
            ),
          ],
          'walls' => <FakeDocRow>[
            (
              id: 'wall-1',
              data: <String, dynamic>{
                'id': 'wall-1',
                'wallpaper_url': '',
                'originalProtected': true,
                'wallpaper_path': '',
                'wallpaper_sha': '',
                'wallpaper_thumb': 'https://example.com/current-thumb.jpg',
                'review': true,
                'collections': <String>['premium'],
              },
            ),
          ],
          _ => throw StateError('Unexpected collection: ${spec.collection}'),
        },
      );

  @override
  Stream<({List<T> items, bool isFromCache})> watchQueryWithMetadata<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  ) async* {
    yield (items: await query(spec, map), isFromCache: false);
  }
}

void main() {
  test('favourite reload uses current premium collection instead of saved free collection', () async {
    final firestore = _FavouriteAndCanonicalFirestore();
    final repository = FavouriteWallsRepositoryImpl(
      firestore,
      FavoritesLocalDataSource(InMemoryLocalStore(), durableStore: _MemoryDurableStore()),
      unusedGuestStore(),
      PrismWallpaperRepositoryImpl(
        firestore,
        FeedCacheLocalDataSource(store: _MemoryDurableStore()),
        FakeUserBlockRepository.pending()..completeInitial(<String>{}),
      ),
    );

    final result = await repository.fetchFavourites(userId: 'user-1');

    expect(result.isSuccess, isTrue, reason: '${result.failure}');
    final wall = result.data!.single as PrismFavouriteWall;
    expect(wall.id, 'wall-1');
    expect(wall.wallpaper.collections, <String>['premium']);
    expect(wall.fullUrl, isEmpty);
    expect(wall.thumbnailUrl, 'https://example.com/current-thumb.jpg');
    final canonicalQuery = firestore.querySpecs.singleWhere((spec) => spec.collection == 'walls');
    expect(canonicalQuery.cachePolicy, FirestoreCachePolicy.serverOnly);
    expect(
      canonicalQuery.filters.any(
        (filter) => filter.field == 'id' && filter.op == FirestoreFilterOp.isEqualTo && filter.value == 'wall-1',
      ),
      isTrue,
    );
  });
}
