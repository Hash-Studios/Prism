import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/data/repositories/favourite_walls_repository_impl.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../support/fake_firestore_client.dart';
import '../../../../support/in_memory_local_store.dart';

class _BatchRecorder implements FirestoreBatch {
  final List<String> deleted = <String>[];

  @override
  void addDoc(String collection, Map<String, dynamic> data) => throw UnimplementedError();

  @override
  void updateDoc(String collection, String id, Map<String, dynamic> data) => throw UnimplementedError();

  @override
  void deleteDoc(String collection, String id) => deleted.add('$collection/$id');
}

class _BatchingFirestore extends FakeFirestoreClient {
  final List<List<String>> batches = <List<String>>[];
  Object? batchError;

  @override
  Future<void> runBatch(Future<void> Function(FirestoreBatch batch) action, {required String sourceTag}) async {
    final recorder = _BatchRecorder();
    await action(recorder);
    final Object? error = batchError;
    if (error != null) throw error;
    batches.add(recorder.deleted);
  }
}

void main() {
  test('successful fetch replaces stale IDs only in the fetched account cache', () async {
    final local = FavoritesLocalDataSource(InMemoryLocalStore());
    await local.setWallFavourite('user_a', 'stale_a', true);
    await local.setWallFavourite('user_b', 'stale_b', true);
    final firestore = FakeFirestoreClient(
      onQuery: (_) => <FakeDocRow>[
        (id: 'doc_1', data: <String, dynamic>{'id': 'wall_b1', 'provider': 'prism'}),
        (id: 'doc_2', data: <String, dynamic>{'id': 'wall_b2', 'provider': 'pexels'}),
      ],
    );
    final repository = FavouriteWallsRepositoryImpl(firestore, local);

    final Result<List<FavouriteWallEntity>> result = await repository.fetchFavourites(userId: 'user_b');

    expect(result.isSuccess, isTrue);
    expect(firestore.querySpecs.single.limit, isNull);
    expect(local.isWallFavourite('user_a', 'stale_a'), isTrue);
    expect(local.isWallFavourite('user_b', 'stale_b'), isFalse);
    expect(local.isWallFavourite('user_b', 'wall_b1'), isTrue);
    expect(local.isWallFavourite('user_b', 'wall_b2'), isTrue);
  });

  test('failed fetch preserves the account local cache', () async {
    final local = FavoritesLocalDataSource(InMemoryLocalStore());
    await local.setWallFavourite('user_b', 'cached_b', true);
    final firestore = FakeFirestoreClient()..queryError = StateError('offline');
    final repository = FavouriteWallsRepositoryImpl(firestore, local);

    final Result<List<FavouriteWallEntity>> result = await repository.fetchFavourites(userId: 'user_b');

    expect(result.isFailure, isTrue);
    expect(local.isWallFavourite('user_b', 'cached_b'), isTrue);
  });

  test('clearAll deletes in batches, skips blank ids and updates the local cache', () async {
    final local = FavoritesLocalDataSource(InMemoryLocalStore());
    final ids = List<String>.generate(450, (i) => 'w$i');
    for (final id in ids) {
      await local.setWallFavourite('u', id, true);
    }
    final firestore = _BatchingFirestore();
    final repository = FavouriteWallsRepositoryImpl(firestore, local);

    final result = await repository.clearAll(userId: 'u', wallIds: <String>[...ids, ' ', 'w0']);

    expect(result.isSuccess, isTrue);
    expect(firestore.batches.map((batch) => batch.length), <int>[400, 50]);
    expect(firestore.batches.first.first, 'usersv2/u/images/w0');
    expect(firestore.writes, isEmpty);
    expect(local.isWallFavourite('u', 'w0'), isFalse);
    expect(local.isWallFavourite('u', 'w449'), isFalse);
  });

  test('clearAll failure keeps the local cache and reports an error', () async {
    final local = FavoritesLocalDataSource(InMemoryLocalStore());
    await local.setWallFavourite('u', 'w1', true);
    final firestore = _BatchingFirestore()..batchError = StateError('offline');
    final repository = FavouriteWallsRepositoryImpl(firestore, local);

    final result = await repository.clearAll(userId: 'u', wallIds: <String>['w1']);

    expect(result.isFailure, isTrue);
    expect(local.isWallFavourite('u', 'w1'), isTrue);
  });
}
