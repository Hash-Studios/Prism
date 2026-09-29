import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/data/repositories/favourite_walls_repository_impl.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../support/in_memory_local_store.dart';

class _FakeFirestoreClient extends Fake implements FirestoreClient {
  List<({String id, Map<String, dynamic> data})> rows = <({String id, Map<String, dynamic> data})>[];
  Object? queryError;
  FirestoreQuerySpec? lastSpec;

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    lastSpec = spec;
    final Object? error = queryError;
    if (error != null) {
      throw error;
    }
    return rows.map((row) => map(row.data, row.id)).toList(growable: false);
  }
}

void main() {
  test('successful fetch replaces stale IDs only in the fetched account cache', () async {
    final local = FavoritesLocalDataSource(InMemoryLocalStore());
    await local.setWallFavourite('user_a', 'stale_a', true);
    await local.setWallFavourite('user_b', 'stale_b', true);
    final firestore = _FakeFirestoreClient()
      ..rows = <({String id, Map<String, dynamic> data})>[
        (id: 'doc_1', data: <String, dynamic>{'id': 'wall_b1', 'provider': 'prism'}),
        (id: 'doc_2', data: <String, dynamic>{'id': 'wall_b2', 'provider': 'pexels'}),
      ];
    final repository = FavouriteWallsRepositoryImpl(firestore, local);

    final Result<List<FavouriteWallEntity>> result = await repository.fetchFavourites(userId: 'user_b');

    expect(result.isSuccess, isTrue);
    expect(firestore.lastSpec!.limit, isNull);
    expect(local.isWallFavourite('user_a', 'stale_a'), isTrue);
    expect(local.isWallFavourite('user_b', 'stale_b'), isFalse);
    expect(local.isWallFavourite('user_b', 'wall_b1'), isTrue);
    expect(local.isWallFavourite('user_b', 'wall_b2'), isTrue);
  });

  test('failed fetch preserves the account local cache', () async {
    final local = FavoritesLocalDataSource(InMemoryLocalStore());
    await local.setWallFavourite('user_b', 'cached_b', true);
    final firestore = _FakeFirestoreClient()..queryError = StateError('offline');
    final repository = FavouriteWallsRepositoryImpl(firestore, local);

    final Result<List<FavouriteWallEntity>> result = await repository.fetchFavourites(userId: 'user_b');

    expect(result.isFailure, isTrue);
    expect(local.isWallFavourite('user_b', 'cached_b'), isTrue);
  });
}
