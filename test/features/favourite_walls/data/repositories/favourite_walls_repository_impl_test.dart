// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/data/repositories/favourite_walls_repository_impl.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../support/fake_firestore_client.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../support/fav_fixtures.dart';
import '../../support/guest_store_fixture.dart';

class _BatchRecorder implements FirestoreBatch {
  final List<String> deleted = <String>[];

  @override
  void addDoc(String collection, Map<String, dynamic> data) => throw UnimplementedError();

  @override
  void setDoc(String collection, String id, Map<String, dynamic> data) => throw UnimplementedError();

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

/// A Firestore whose writes never finish, like a write made with no network.
class _OfflineWriteFirestore extends FakeFirestoreClient {
  Object? writeError;

  @override
  Future<void> setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
    required String sourceTag,
  }) {
    writes.add((op: 'set', collection: collection, id: id, data: data));
    final Object? error = writeError;
    return error == null ? Completer<void>().future : Future<void>.error(error);
  }

  @override
  Future<void> deleteDoc(String collection, String id, {required String sourceTag}) {
    writes.add((op: 'delete', collection: collection, id: id, data: null));
    final Object? error = writeError;
    return error == null ? Completer<void>().future : Future<void>.error(error);
  }

  @override
  Future<void> runBatch(Future<void> Function(FirestoreBatch batch) action, {required String sourceTag}) {
    return Completer<void>().future;
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
    final repository = FavouriteWallsRepositoryImpl(firestore, local, unusedGuestStore());

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
    final repository = FavouriteWallsRepositoryImpl(firestore, local, unusedGuestStore());

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
    final repository = FavouriteWallsRepositoryImpl(firestore, local, unusedGuestStore());

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
    final repository = FavouriteWallsRepositoryImpl(firestore, local, unusedGuestStore());

    final result = await repository.clearAll(userId: 'u', wallIds: <String>['w1']);

    expect(result.isFailure, isTrue);
    expect(local.isWallFavourite('u', 'w1'), isTrue);
  });

  group('offline writes', () {
    test('a heart tap with no network finishes after 8 seconds, keeps the local heart and reports success', () {
      fakeAsync((async) {
        final local = FavoritesLocalDataSource(InMemoryLocalStore());
        final repository = FavouriteWallsRepositoryImpl(_OfflineWriteFirestore(), local, unusedGuestStore());
        Result<bool>? result;

        repository
            .toggleFavourite(userId: 'u', wall: prismFav('w1'), currentlyFavourited: false)
            .then((value) => result = value);
        async.elapse(const Duration(seconds: 7));
        expect(result, isNull);
        expect(local.isWallFavourite('u', 'w1'), isTrue, reason: 'the local heart flips before the server answers');

        async.elapse(const Duration(seconds: 2));

        expect(result?.isSuccess, isTrue);
        expect(result?.data, isTrue);
        expect(local.isWallFavourite('u', 'w1'), isTrue);
      });
    });

    test('an offline removal also clears the local heart at once and succeeds after the timeout', () {
      fakeAsync((async) {
        final local = FavoritesLocalDataSource(InMemoryLocalStore());
        local.setWallFavourite('u', 'w1', true);
        async.flushMicrotasks();
        final repository = FavouriteWallsRepositoryImpl(_OfflineWriteFirestore(), local, unusedGuestStore());
        Result<bool>? result;

        repository
            .toggleFavourite(userId: 'u', wall: prismFav('w1'), currentlyFavourited: true)
            .then((value) => result = value);
        async.elapse(const Duration(seconds: 9));

        expect(result?.data, isFalse);
        expect(local.isWallFavourite('u', 'w1'), isFalse);
      });
    });

    test('permission-denied rolls the local heart back and reports a failure', () async {
      final local = FavoritesLocalDataSource(InMemoryLocalStore());
      final firestore = _OfflineWriteFirestore()..writeError = FirestoreError(message: 'no', code: 'permission-denied');
      final repository = FavouriteWallsRepositoryImpl(firestore, local, unusedGuestStore());

      final result = await repository.toggleFavourite(userId: 'u', wall: prismFav('w1'), currentlyFavourited: false);

      expect(result.isFailure, isTrue);
      expect(local.isWallFavourite('u', 'w1'), isFalse);
    });

    test('clearAll with no network finishes after the timeout and keeps the hearts cleared', () {
      fakeAsync((async) {
        final local = FavoritesLocalDataSource(InMemoryLocalStore());
        local.setWallFavourite('u', 'w1', true);
        async.flushMicrotasks();
        final repository = FavouriteWallsRepositoryImpl(_OfflineWriteFirestore(), local, unusedGuestStore());
        Result<bool>? result;

        repository.clearAll(userId: 'u', wallIds: <String>['w1']).then((value) => result = value);
        async.elapse(const Duration(seconds: 9));

        expect(result?.isSuccess, isTrue);
        expect(local.isWallFavourite('u', 'w1'), isFalse);
      });
    });
  });

  group('favouritedAt', () {
    test('every source writes favouritedAt and keeps the one the entity already has', () async {
      final firestore = FakeFirestoreClient();
      final repository = FavouriteWallsRepositoryImpl(
        firestore,
        FavoritesLocalDataSource(InMemoryLocalStore()),
        unusedGuestStore(),
      );
      final DateTime stamped = DateTime.utc(2026, 5);

      for (final FavouriteWallEntity wall in <FavouriteWallEntity>[
        prismFav('p'),
        wallhavenFav('h'),
        pexelsFav('x'),
        legacyFav('l'),
      ]) {
        await repository.toggleFavourite(userId: 'u', wall: wall, currentlyFavourited: false);
      }
      await repository.toggleFavourite(
        userId: 'u',
        wall: pexelsFav('stamped').withFavouritedAt(stamped),
        currentlyFavourited: false,
      );

      for (final write in firestore.writes) {
        expect(write.data!['favouritedAt'], isA<DateTime>(), reason: '${write.id} has favouritedAt');
      }
      expect(firestore.writes.last.data!['favouritedAt'], stamped);
    });

    test('a fetched list is ordered by favouritedAt, falling back to createdAt for older docs', () async {
      final firestore = FakeFirestoreClient(
        onQuery: (_) => <FakeDocRow>[
          (
            id: 'old_upload',
            data: <String, dynamic>{'id': 'old_upload', 'provider': 'prism', 'createdAt': '2026-01-10T00:00:00Z'},
          ),
          (
            id: 'new_save',
            data: <String, dynamic>{
              'id': 'new_save',
              'provider': 'pexels',
              'createdAt': '2026-01-01T00:00:00Z',
              'favouritedAt': '2026-03-01T00:00:00Z',
            },
          ),
          (
            id: 'mid_save',
            data: <String, dynamic>{
              'id': 'mid_save',
              'provider': 'prism',
              'createdAt': '2025-01-01T00:00:00Z',
              'favouritedAt': '2026-02-01T00:00:00Z',
            },
          ),
        ],
      );
      final repository = FavouriteWallsRepositoryImpl(
        firestore,
        FavoritesLocalDataSource(InMemoryLocalStore()),
        unusedGuestStore(),
      );

      final result = await repository.fetchFavourites(userId: 'u');

      expect(result.data!.map((wall) => wall.id), <String>['new_save', 'mid_save', 'old_upload']);
      expect(result.data!.first.favouritedAt, DateTime.utc(2026, 3));
    });
  });

  group('guest favourites', () {
    test('a guest save goes to the guest store and the guest heart set, not to Firestore', () async {
      final firestore = FakeFirestoreClient();
      final local = FavoritesLocalDataSource(InMemoryLocalStore());
      final store = tempGuestStore();
      final repository = FavouriteWallsRepositoryImpl(firestore, local, store);

      final result = await repository.toggleFavourite(userId: '', wall: pexelsFav('g1'), currentlyFavourited: false);

      expect(result.data, isTrue);
      expect(firestore.writes, isEmpty);
      expect(local.isWallFavourite('', 'g1'), isTrue);
      expect((await store.readAll()).keys, <String>['g1']);
    });

    test('a guest list reads back from the store and a guest removal deletes from it', () async {
      final local = FavoritesLocalDataSource(InMemoryLocalStore());
      final store = tempGuestStore();
      final repository = FavouriteWallsRepositoryImpl(FakeFirestoreClient(), local, store);
      await repository.toggleFavourite(userId: '', wall: pexelsFav('g1'), currentlyFavourited: false);
      await repository.toggleFavourite(userId: '', wall: prismFav('g2'), currentlyFavourited: false);

      final fetched = await repository.fetchFavourites(userId: '');
      expect(fetched.data!.map((wall) => wall.id), unorderedEquals(<String>['g1', 'g2']));
      expect(fetched.data!.every((wall) => wall.favouritedAt != null), isTrue);

      await repository.toggleFavourite(userId: '', wall: pexelsFav('g1'), currentlyFavourited: true);
      final clearResult = await repository.clearAll(userId: '', wallIds: <String>['g2']);

      expect(clearResult.isSuccess, isTrue);
      expect(await store.readAll(), isEmpty);
      expect(local.isWallFavourite('', 'g1'), isFalse);
      expect(local.isWallFavourite('', 'g2'), isFalse);
    });
  });
}
