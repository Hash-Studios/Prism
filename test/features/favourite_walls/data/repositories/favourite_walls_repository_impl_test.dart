// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/data/favourite_wall_doc_mapper.dart';
import 'package:Prism/features/favourite_walls/data/repositories/favourite_walls_repository_impl.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_firestore_client.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../support/canonical_fixture.dart';
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

class _MetadataFirestore extends FakeFirestoreClient {
  _MetadataFirestore({super.onQuery});

  bool cacheOnlyEmpty = false;
  List<FakeDocRow>? cacheRows;
  bool neverEmitServer = false;

  @override
  Stream<({List<T> items, bool isFromCache})> watchQueryWithMetadata<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  ) {
    querySpecs.add(spec);
    final Object? error = queryError;
    if (error != null) return Stream<({List<T> items, bool isFromCache})>.error(error);
    if (cacheOnlyEmpty) {
      return Stream<({List<T> items, bool isFromCache})>.value((items: <T>[], isFromCache: true));
    }
    final List<FakeDocRow>? cached = cacheRows;
    final cacheSnapshot = cached == null
        ? null
        : (items: cached.map((row) => map(row.data, row.id)).toList(growable: false), isFromCache: true);
    if (neverEmitServer && cacheSnapshot != null) {
      late final StreamController<({List<T> items, bool isFromCache})> controller;
      controller = StreamController<({List<T> items, bool isFromCache})>(
        onListen: () => controller.add(cacheSnapshot),
        onCancel: () {},
      );
      return controller.stream;
    }
    final rows = onQuery?.call(spec) ?? const <FakeDocRow>[];
    final serverSnapshot = (
      items: rows.map((row) => map(row.data, row.id)).toList(growable: false),
      isFromCache: false,
    );
    return Stream<({List<T> items, bool isFromCache})>.fromIterable(<({List<T> items, bool isFromCache})>[
      if (cacheSnapshot != null) cacheSnapshot,
      serverSnapshot,
    ]);
  }
}

class _NeverServerControllerFirestore extends _MetadataFirestore {
  bool cancelled = false;
  Object? cancelError;
  void Function()? emitCache;
  void Function()? emitServerEmpty;
  void Function()? emitError;

  @override
  Stream<({List<T> items, bool isFromCache})> watchQueryWithMetadata<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  ) {
    querySpecs.add(spec);
    late final StreamController<({List<T> items, bool isFromCache})> controller;
    controller = StreamController<({List<T> items, bool isFromCache})>(
      onCancel: () {
        cancelled = true;
        final Object? error = cancelError;
        if (error != null) return Future<void>.error(error);
      },
    );
    emitCache = () => controller.add((
      items: <T>[
        map(<String, dynamic>{'id': 'sdk_cached', 'provider': 'prism'}, 'sdk_cached'),
      ],
      isFromCache: true,
    ));
    emitServerEmpty = () => controller.add((items: <T>[], isFromCache: false));
    emitError = () => controller.addError(StateError('server read failed'));
    return controller.stream;
  }
}

class _MemoryDurableStore extends DurableJsonStore {
  _MemoryDurableStore() : super('favourites');

  final Map<String, Map<String, Object?>> records = <String, Map<String, Object?>>{};

  @override
  Future<Map<String, Object?>?> read(String key) async {
    return records[key];
  }

  @override
  Future<Map<String, Map<String, Object?>>> readAll() async {
    return Map<String, Map<String, Object?>>.of(records);
  }

  @override
  Future<void> write(String key, Map<String, Object?> value) async {
    records[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    records.remove(key);
  }
}

FavoritesLocalDataSource _local() =>
    FavoritesLocalDataSource(InMemoryLocalStore(), durableStore: _MemoryDurableStore());

class _BatchingFirestore extends _MetadataFirestore {
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
class _OfflineWriteFirestore extends _MetadataFirestore {
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
    final Object? error = writeError;
    return error == null ? Completer<void>().future : Future<void>.error(error);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (_) async => Directory.systemTemp.path,
  );
  test('successful fetch replaces stale IDs only in the fetched account cache', () async {
    final local = _local();
    await local.setWallFavourite('user_a', 'stale_a', true);
    await local.setWallFavourite('user_b', 'stale_b', true);
    final firestore = _MetadataFirestore(
      onQuery: (_) => <FakeDocRow>[
        (id: 'doc_1', data: <String, dynamic>{'id': 'wall_b1', 'provider': 'prism'}),
        (id: 'doc_2', data: <String, dynamic>{'id': 'wall_b2', 'provider': 'pexels'}),
      ],
    );
    final repository = FavouriteWallsRepositoryImpl(
      firestore,
      local,
      unusedGuestStore(),
      EmptyCanonicalWallpaperRepository(),
    );

    final Result<List<FavouriteWallEntity>> result = await repository.fetchFavourites(userId: 'user_b');

    expect(result.isSuccess, isTrue, reason: result.failure?.message);
    expect(firestore.querySpecs.single.limit, isNull);
    expect(local.isWallFavourite('user_a', 'stale_a'), isTrue);
    expect(local.isWallFavourite('user_b', 'stale_b'), isFalse);
    expect(local.isWallFavourite('user_b', 'wall_b1'), isTrue);
    expect(local.isWallFavourite('user_b', 'wall_b2'), isTrue);
  });

  test('failed fetch preserves the account local cache', () async {
    final local = _local();
    await local.setWallFavourite('user_b', 'cached_b', true);
    final firestore = _MetadataFirestore()..queryError = StateError('offline');
    final repository = FavouriteWallsRepositoryImpl(
      firestore,
      local,
      unusedGuestStore(),
      EmptyCanonicalWallpaperRepository(),
    );

    final Result<List<FavouriteWallEntity>> result = await repository.fetchFavourites(userId: 'user_b');

    expect(result.isFailure, isTrue);
    expect(local.isWallFavourite('user_b', 'cached_b'), isTrue);
  });

  test('an empty cache snapshot does not erase the saved snapshot before server metadata arrives', () async {
    final local = _local();
    await local.updateWallSnapshot('user_b', (_) => <FavouriteWallEntity>[prismFav('saved_wall')]);
    final repository = FavouriteWallsRepositoryImpl(
      _MetadataFirestore()..cacheOnlyEmpty = true,
      local,
      unusedGuestStore(),
      EmptyCanonicalWallpaperRepository(),
    );

    final result = await repository.fetchFavourites(userId: 'user_b');

    expect(result.isSuccess, isTrue);
    expect(result.data!.single.id, 'saved_wall');
    expect((await local.readWallSnapshot('user_b')).single.id, 'saved_wall');
  });

  test('a nonempty SDK cache snapshot is returned after a short grace when server metadata never arrives', () {
    fakeAsync((async) {
      final durable = _MemoryDurableStore();
      final local = FavoritesLocalDataSource(InMemoryLocalStore(), durableStore: durable);
      expect(durable.records, isEmpty);
      final firestore = _MetadataFirestore()
        ..cacheRows = <FakeDocRow>[
          (id: 'sdk_cached', data: <String, dynamic>{'id': 'sdk_cached', 'provider': 'prism'}),
        ]
        ..neverEmitServer = true;
      final repository = FavouriteWallsRepositoryImpl(
        firestore,
        local,
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
      );
      Result<List<FavouriteWallEntity>>? result;

      unawaited(repository.fetchFavourites(userId: 'user_b').then((value) => result = value));
      async.flushMicrotasks();
      expect(result, isNull);
      async.elapse(const Duration(milliseconds: 499));
      async.flushMicrotasks();
      expect(result, isNull);
      async.elapse(const Duration(milliseconds: 1));
      async.flushMicrotasks();

      expect(result?.isSuccess, isTrue, reason: result?.failure?.message);
      expect(result?.data?.map((wall) => wall.id), <String>['sdk_cached']);
    });
  });

  test('a cached metadata read cancels the Firestore subscription after the grace period', () {
    fakeAsync((async) {
      final local = _local();
      final firestore = _NeverServerControllerFirestore();
      final repository = FavouriteWallsRepositoryImpl(
        firestore,
        local,
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
      );
      Result<List<FavouriteWallEntity>>? result;

      unawaited(repository.fetchFavourites(userId: 'user_b').then((value) => result = value));
      async.flushMicrotasks();
      firestore.emitCache!();
      async.flushMicrotasks();
      expect(firestore.cancelled, isFalse);

      async.elapse(const Duration(milliseconds: 500));
      async.flushMicrotasks();

      expect(result?.isSuccess, isTrue, reason: result?.failure?.message);
      expect(result?.data?.map((wall) => wall.id), <String>['sdk_cached']);
      expect(firestore.cancelled, isTrue);
    });
  });

  test('a metadata read with no SDK cache keeps the full server timeout', () {
    fakeAsync((async) {
      final firestore = _NeverServerControllerFirestore();
      final repository = FavouriteWallsRepositoryImpl(
        firestore,
        _local(),
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
      );
      Result<List<FavouriteWallEntity>>? result;

      unawaited(repository.fetchFavourites(userId: 'user_b').then((value) => result = value));
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 7999));
      async.flushMicrotasks();
      expect(result, isNull);

      async.elapse(const Duration(milliseconds: 1));
      async.flushMicrotasks();

      expect(result?.isSuccess, isTrue, reason: result?.failure?.message);
      expect(result?.data, isEmpty);
      expect(firestore.cancelled, isTrue);
    });
  });

  test('a metadata cleanup failure does not prevent the bounded cached result', () {
    fakeAsync((async) {
      final firestore = _NeverServerControllerFirestore()..cancelError = StateError('cleanup failed');
      final repository = FavouriteWallsRepositoryImpl(
        firestore,
        _local(),
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
      );
      Result<List<FavouriteWallEntity>>? result;

      unawaited(repository.fetchFavourites(userId: 'user_b').then((value) => result = value));
      async.flushMicrotasks();
      firestore.emitCache!();
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 500));
      async.flushMicrotasks();

      expect(result?.isSuccess, isTrue, reason: result?.failure?.message);
      expect(result?.data?.map((wall) => wall.id), <String>['sdk_cached']);
      expect(firestore.cancelled, isTrue);
    });
  });

  test('a server-confirmed empty snapshot within the cache grace clears the saved snapshot', () {
    fakeAsync((async) {
      final local = _local();
      local.updateWallSnapshot('user_b', (_) => <FavouriteWallEntity>[prismFav('stale_wall')]);
      async.flushMicrotasks();
      final firestore = _NeverServerControllerFirestore();
      final repository = FavouriteWallsRepositoryImpl(
        firestore,
        local,
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
      );
      Result<List<FavouriteWallEntity>>? result;

      unawaited(repository.fetchFavourites(userId: 'user_b').then((value) => result = value));
      async.flushMicrotasks();
      firestore.emitCache!();
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 250));
      expect(result, isNull);
      firestore.emitServerEmpty!();
      async.flushMicrotasks();

      expect(result?.isSuccess, isTrue, reason: result?.failure?.message);
      expect(result?.data, isEmpty);
      expect(firestore.cancelled, isTrue);
    });
  });

  test('a server error during the cache grace returns cached data without an unhandled error', () {
    fakeAsync((async) {
      final firestore = _NeverServerControllerFirestore();
      final repository = FavouriteWallsRepositoryImpl(
        firestore,
        _local(),
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
      );
      Result<List<FavouriteWallEntity>>? result;

      unawaited(repository.fetchFavourites(userId: 'user_b').then((value) => result = value));
      async.flushMicrotasks();
      firestore.emitCache!();
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 250));
      firestore.emitError!();
      async.flushMicrotasks();

      expect(result?.isSuccess, isTrue, reason: result?.failure?.message);
      expect(result?.data?.map((wall) => wall.id), <String>['sdk_cached']);
      expect(firestore.cancelled, isTrue);
    });
  });

  test('server-confirmed empty favourites clear the stale local snapshot', () async {
    final local = _local();
    await local.updateWallSnapshot('user_b', (_) => <FavouriteWallEntity>[prismFav('removed_elsewhere')]);
    final repository = FavouriteWallsRepositoryImpl(
      _MetadataFirestore(),
      local,
      unusedGuestStore(),
      EmptyCanonicalWallpaperRepository(),
    );

    final result = await repository.fetchFavourites(userId: 'user_b');

    expect(result.isSuccess, isTrue);
    expect(result.data, isEmpty);
    expect(await local.readWallSnapshot('user_b'), isEmpty);
  });

  test('failed refresh returns the full favourite snapshot saved before restart', () async {
    final directory = await Directory.systemTemp.createTemp('prism-favourites-test-');
    final store = tempGuestStore();
    final local = FavoritesLocalDataSource(
      InMemoryLocalStore(),
      durableStore: DurableJsonStore('favourites', directory: directory),
    );
    final online = FavouriteWallsRepositoryImpl(
      _MetadataFirestore(),
      local,
      store,
      EmptyCanonicalWallpaperRepository(),
    );
    await online.toggleFavourite(userId: 'user_b', wall: prismFav('saved_wall'), currentlyFavourited: false);

    final restarted = FavouriteWallsRepositoryImpl(
      _MetadataFirestore()..queryError = StateError('offline'),
      FavoritesLocalDataSource(
        InMemoryLocalStore(),
        durableStore: DurableJsonStore('favourites', directory: directory),
      ),
      store,
      EmptyCanonicalWallpaperRepository(),
    );

    final Result<List<FavouriteWallEntity>> result = await restarted.fetchFavourites(userId: 'user_b');

    expect(result.isSuccess, isTrue, reason: result.failure?.message);
    expect(result.data!.single.id, 'saved_wall');
    expect(result.data!.single.fullUrl, prismFav('saved_wall').fullUrl);
    await directory.delete(recursive: true);
  });

  test('an old acknowledgement cannot replace a newer desired revision or another account', () async {
    final directory = await Directory.systemTemp.createTemp('prism-favourite-outbox-');
    final local = FavoritesLocalDataSource(
      InMemoryLocalStore(),
      durableStore: DurableJsonStore('favourites', directory: directory),
    );
    final first = await local.createFavouriteOperation('account_a', 'wall', desired: true, wall: <String, Object?>{});
    final latest = await local.createFavouriteOperation('account_a', 'wall', desired: false, wall: <String, Object?>{});
    await local.createFavouriteOperation('account_b', 'wall', desired: true, wall: <String, Object?>{});

    expect(
      await local.updateFavouriteOperationStatus(
        'account_a',
        'wall',
        first['operationId']! as String,
        status: 'synced',
      ),
      isFalse,
    );
    expect((await local.readFavouriteOperation('account_a', 'wall'))!['operationId'], latest['operationId']);
    expect((await local.readFavouriteOperation('account_a', 'wall'))!['status'], 'pending');
    expect((await local.readFavouriteOperation('account_b', 'wall'))!['status'], 'pending');
    await directory.delete(recursive: true);
  });

  test('a delayed retry skips an operation superseded by a newer desired revision', () async {
    final local = _local();
    final first = await local.createFavouriteOperation('owner', 'wall', desired: true, wall: <String, Object?>{});
    final Completer<void> delayedSend = Completer<void>();
    final Completer<void> sendStarted = Completer<void>();
    final send = local.runFavouriteOperationsIfCurrent(
      'owner',
      <String, String>{'wall': first['operationId']! as String},
      () {
        sendStarted.complete();
        return delayedSend.future;
      },
    );
    await sendStarted.future;
    final newerIntent = local.createFavouriteOperation('owner', 'wall', desired: false, wall: <String, Object?>{});
    delayedSend.complete();
    expect(await send, isTrue);
    final latest = await newerIntent;
    var staleSendCount = 0;

    final bool staleWasSent = await local.runFavouriteOperationsIfCurrent('owner', <String, String>{
      'wall': first['operationId']! as String,
    }, () async => staleSendCount++);

    expect(staleWasSent, isFalse);
    expect(staleSendCount, 0);
    expect((await local.readFavouriteOperation('owner', 'wall'))!['operationId'], latest['operationId']);
    expect((await local.readFavouriteOperation('owner', 'wall'))!['desired'], isFalse);
    expect((await local.readFavouriteOperation('owner', 'wall'))!['status'], 'pending');
  });

  test('large favourite snapshots are sharded and remain readable as one snapshot', () async {
    final durable = _MemoryDurableStore();
    final local = FavoritesLocalDataSource(InMemoryLocalStore(), durableStore: durable);
    final metadata = List<FavouriteWallEntity>.generate(
      1200,
      (index) => prismFav('large-$index', category: 'metadata' * 80),
    );

    await local.updateWallSnapshot('large-owner', (_) => metadata);

    expect(await local.readWallSnapshot('large-owner'), hasLength(1200));
    expect(durable.records.keys.where((key) => key.startsWith('large-owner::snapshot:')), hasLength(greaterThan(1)));
  });

  test('clearAll deletes in batches, skips blank ids and updates the local cache', () async {
    final local = _local();
    final ids = List<String>.generate(450, (i) => 'w$i');
    for (final id in ids) {
      await local.setWallFavourite('u', id, true);
    }
    final firestore = _BatchingFirestore();
    final repository = FavouriteWallsRepositoryImpl(
      firestore,
      local,
      unusedGuestStore(),
      EmptyCanonicalWallpaperRepository(),
    );

    final result = await repository.clearAll(userId: 'u', wallIds: <String>[...ids, ' ', 'w0']);

    expect(result.isSuccess, isTrue);
    expect(firestore.batches.map((batch) => batch.length), <int>[400, 50]);
    expect(firestore.batches.first.first, 'usersv2/u/images/w0');
    expect(firestore.writes, isEmpty);
    expect(local.isWallFavourite('u', 'w0'), isFalse);
    expect(local.isWallFavourite('u', 'w449'), isFalse);
  });

  test('clearAll failure keeps the local cache and reports an error', () async {
    final local = _local();
    await local.setWallFavourite('u', 'w1', true);
    final firestore = _BatchingFirestore()..batchError = FirestoreError(message: 'denied', code: 'permission-denied');
    final repository = FavouriteWallsRepositoryImpl(
      firestore,
      local,
      unusedGuestStore(),
      EmptyCanonicalWallpaperRepository(),
    );

    final result = await repository.clearAll(userId: 'u', wallIds: <String>['w1']);

    expect(result.isFailure, isTrue);
    expect(local.isWallFavourite('u', 'w1'), isTrue);
    expect((await local.readFavouriteOperation('u', 'w1'))!['status'], 'rejected');
  });

  group('offline writes', () {
    test('a heart tap with no network finishes after 8 seconds, keeps the local heart and reports success', () {
      fakeAsync((async) {
        final local = _local();
        final repository = FavouriteWallsRepositoryImpl(
          _OfflineWriteFirestore(),
          local,
          unusedGuestStore(),
          EmptyCanonicalWallpaperRepository(),
        );
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
        Map<String, Object?>? operation;
        unawaited(local.readFavouriteOperation('u', 'w1').then((value) => operation = value));
        async.flushMicrotasks();
        expect(operation?['status'], 'pending');
      });
    });

    test('an offline removal also clears the local heart at once and succeeds after the timeout', () {
      fakeAsync((async) {
        final local = _local();
        local.setWallFavourite('u', 'w1', true);
        async.flushMicrotasks();
        final repository = FavouriteWallsRepositoryImpl(
          _OfflineWriteFirestore(),
          local,
          unusedGuestStore(),
          EmptyCanonicalWallpaperRepository(),
        );
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
      final local = _local();
      final firestore = _OfflineWriteFirestore()..writeError = FirestoreError(message: 'no', code: 'permission-denied');
      final repository = FavouriteWallsRepositoryImpl(
        firestore,
        local,
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
      );

      final result = await repository.toggleFavourite(userId: 'u', wall: prismFav('w1'), currentlyFavourited: false);

      expect(result.isFailure, isTrue);
      expect(local.isWallFavourite('u', 'w1'), isFalse);
      expect((await local.readFavouriteOperation('u', 'w1'))!['status'], 'rejected');
    });

    test('an immediate unavailable error keeps the durable favourite intent pending', () async {
      final local = _local();
      final firestore = _OfflineWriteFirestore()..writeError = FirestoreError(message: 'offline', code: 'unavailable');
      final repository = FavouriteWallsRepositoryImpl(
        firestore,
        local,
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
      );

      final result = await repository.toggleFavourite(userId: 'u', wall: prismFav('w1'), currentlyFavourited: false);

      expect(result.isSuccess, isTrue);
      expect(local.isWallFavourite('u', 'w1'), isTrue);
      expect((await local.readFavouriteOperation('u', 'w1'))!['status'], 'pending');
    });

    test('an immediate unavailable clear keeps removals pending without restoring local hearts', () async {
      final local = _local();
      await local.setWallFavourite('u', 'w1', true);
      final firestore = _OfflineWriteFirestore()..writeError = FirestoreError(message: 'offline', code: 'unavailable');
      final repository = FavouriteWallsRepositoryImpl(
        firestore,
        local,
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
      );

      final result = await repository.clearAll(userId: 'u', wallIds: <String>['w1']);

      expect(result.isSuccess, isTrue);
      expect(local.isWallFavourite('u', 'w1'), isFalse);
      expect((await local.readFavouriteOperation('u', 'w1'))!['status'], 'pending');
    });

    test('clearAll with no network finishes after the timeout and keeps the hearts cleared', () {
      fakeAsync((async) {
        final local = _local();
        local.setWallFavourite('u', 'w1', true);
        async.flushMicrotasks();
        final repository = FavouriteWallsRepositoryImpl(
          _OfflineWriteFirestore(),
          local,
          unusedGuestStore(),
          EmptyCanonicalWallpaperRepository(),
        );
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
      final firestore = _MetadataFirestore();
      final repository = FavouriteWallsRepositoryImpl(
        firestore,
        _local(),
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
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
      final firestore = _MetadataFirestore(
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
        _local(),
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
      );

      final result = await repository.fetchFavourites(userId: 'u');

      expect(result.data!.map((wall) => wall.id), <String>['new_save', 'mid_save', 'old_upload']);
      expect(result.data!.first.favouritedAt, DateTime.utc(2026, 3));
    });
  });

  group('guest favourites', () {
    test('a guest save goes to the guest store and the guest heart set, not to Firestore', () async {
      final firestore = _MetadataFirestore();
      final local = _local();
      final store = tempGuestStore();
      final repository = FavouriteWallsRepositoryImpl(firestore, local, store, EmptyCanonicalWallpaperRepository());

      final result = await repository.toggleFavourite(userId: '', wall: pexelsFav('g1'), currentlyFavourited: false);

      expect(result.data, isTrue);
      expect(firestore.writes, isEmpty);
      expect(local.isWallFavourite('', 'g1'), isTrue);
      expect((await store.readAll()).keys, <String>['g1']);
    });

    test('a guest list reads back from the store and a guest removal deletes from it', () async {
      final local = _local();
      final store = tempGuestStore();
      final repository = FavouriteWallsRepositoryImpl(
        _MetadataFirestore(),
        local,
        store,
        EmptyCanonicalWallpaperRepository(),
      );
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

  test('signed-in bundled starter favourites are stored locally without outbox or Firestore writes', () async {
    final local = _local();
    final firestore = _MetadataFirestore();
    final repository = FavouriteWallsRepositoryImpl(
      firestore,
      local,
      unusedGuestStore(),
      EmptyCanonicalWallpaperRepository(),
    );
    final starter = prismFav('starter-sunset');

    final result = await repository.toggleFavourite(userId: 'account', wall: starter, currentlyFavourited: false);

    expect(result.isSuccess, isTrue);
    expect(firestore.writes, isEmpty);
    expect((await local.readFavouriteOperation('account', 'starter-sunset')), isNull);
    expect((await local.readWallSnapshot('account')).single.id, 'starter-sunset');

    final fetched = await repository.fetchFavourites(userId: 'account');
    expect(fetched.data!.single.id, 'starter-sunset');
    expect(firestore.querySpecs, hasLength(1));
    expect(firestore.writes, isEmpty);
  });

  test('clearing a signed-in bundled starter does not enqueue a Firestore delete', () async {
    final local = _local();
    final firestore = _MetadataFirestore();
    final repository = FavouriteWallsRepositoryImpl(
      firestore,
      local,
      unusedGuestStore(),
      EmptyCanonicalWallpaperRepository(),
    );
    final starter = prismFav('starter-sunset');
    await local.updateWallSnapshot('account', (_) => <FavouriteWallEntity>[starter]);
    await local.setWallFavourite('account', starter.id, true);

    final result = await repository.clearAll(userId: 'account', wallIds: <String>[starter.id]);

    expect(result.isSuccess, isTrue);
    expect(firestore.writes, isEmpty);
    expect((await local.readFavouriteOperation('account', starter.id)), isNull);
    expect(local.isWallFavourite('account', starter.id), isFalse);
    expect(await local.readWallSnapshot('account'), isEmpty);
  });

  test('toggleFavourite writes favouritedAt and fetch maps it back', () async {
    final local = _local();
    final firestore = _MetadataFirestore();
    final repository = FavouriteWallsRepositoryImpl(
      firestore,
      local,
      unusedGuestStore(),
      EmptyCanonicalWallpaperRepository(),
    );

    await repository.toggleFavourite(userId: 'u', wall: prismFav('p1'), currentlyFavourited: false);

    expect(firestore.writes.single.data!['favouritedAt'], isA<DateTime>());

    final stamp = DateTime.utc(2026, 3, 4);
    final reader = _MetadataFirestore(
      onQuery: (_) => <FakeDocRow>[
        (id: 'd1', data: <String, dynamic>{'id': 'p1', 'provider': 'prism', 'favouritedAt': stamp}),
      ],
    );
    final result = await FavouriteWallsRepositoryImpl(
      reader,
      local,
      unusedGuestStore(),
      EmptyCanonicalWallpaperRepository(),
    ).fetchFavourites(userId: 'u');

    expect(result.data!.single.favouritedAt, stamp);
  });

  test('older favourite docs keep a null favourite time and can use createdAt', () async {
    final createdAt = DateTime.utc(2022, 5, 6);
    final local = _local();
    final firestore = _MetadataFirestore(
      onQuery: (_) => <FakeDocRow>[
        (id: 'old', data: <String, dynamic>{'id': 'old', 'provider': 'prism', 'createdAt': createdAt}),
      ],
    );

    final result = await FavouriteWallsRepositoryImpl(
      firestore,
      local,
      unusedGuestStore(),
      EmptyCanonicalWallpaperRepository(),
    ).fetchFavourites(userId: 'u');

    expect(result.data!.single.favouritedAt, isNull);
    expect(result.data!.single.addedAt, createdAt);
  });

  test('restoring a removed favourite preserves its original favourite time', () async {
    final stamp = DateTime.utc(2026, 3, 4);
    final local = _local();
    final firestore = _MetadataFirestore();

    await FavouriteWallsRepositoryImpl(
      firestore,
      local,
      unusedGuestStore(),
      EmptyCanonicalWallpaperRepository(),
    ).toggleFavourite(
      userId: 'u',
      wall: prismFav('p1', favouritedAt: stamp),
      currentlyFavourited: false,
    );

    expect(firestore.writes.single.data!['favouritedAt'], stamp);
  });

  test('restoring a removed pinned favourite does not restore its old pin', () async {
    final FavouriteWallEntity wall = prismFav('p1').withPinnedAt(DateTime.utc(2026, 3, 4));
    final _MetadataFirestore firestore = _MetadataFirestore();
    final FavouriteWallsRepositoryImpl repository = FavouriteWallsRepositoryImpl(
      firestore,
      _local(),
      unusedGuestStore(),
      EmptyCanonicalWallpaperRepository(),
    );

    await repository.toggleFavourite(userId: 'u', wall: wall, currentlyFavourited: false);

    expect(firestore.writes.single.data!.containsKey('pinnedAt'), isFalse);
  });

  group('setPinned', () {
    test('signed-in pin writes pinnedAt to the account doc and the local snapshot', () async {
      final stamp = DateTime.utc(2026, 10, 29, 9);
      final local = _local();
      await local.updateWallSnapshot('u1', (_) => <FavouriteWallEntity>[prismFav('p1')]);
      final firestore = _PinWriteFirestore();
      final repository = FavouriteWallsRepositoryImpl(
        firestore,
        local,
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
      );

      final Result<void> result = await repository.setPinned(userId: 'u1', wall: prismFav('p1'), pinnedAt: stamp);

      expect(result.isSuccess, isTrue, reason: result.failure?.message);
      expect(firestore.writes.single.op, 'update');
      expect(firestore.writes.single.collection, 'usersv2/u1/images');
      expect(firestore.writes.single.id, 'p1');
      expect(firestore.writes.single.data, <String, dynamic>{'pinnedAt': stamp});
      expect(firestore.sourceTags, <String>['favourite_walls.pin']);
      final List<FavouriteWallEntity> snapshot = await local.readWallSnapshot('u1');
      expect(snapshot.single.id, 'p1');
      expect(snapshot.single.pinnedAt, stamp);
    });

    test('signed-in unpin writes the delete sentinel and clears the local snapshot', () async {
      final local = _local();
      await local.updateWallSnapshot(
        'u1',
        (_) => <FavouriteWallEntity>[prismFav('p1').withPinnedAt(DateTime.utc(2026))],
      );
      final firestore = _PinWriteFirestore();
      final repository = FavouriteWallsRepositoryImpl(
        firestore,
        local,
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
      );

      final Result<void> result = await repository.setPinned(userId: 'u1', wall: prismFav('p1'));

      expect(result.isSuccess, isTrue, reason: result.failure?.message);
      expect(firestore.writes.single.op, 'update');
      expect(firestore.writes.single.collection, 'usersv2/u1/images');
      expect(firestore.writes.single.id, 'p1');
      expect(firestore.writes.single.data!.keys, <String>['pinnedAt']);
      expect(firestore.writes.single.data!['pinnedAt'], isA<FieldValue>());
      expect(firestore.sourceTags, <String>['favourite_walls.pin']);
      final List<FavouriteWallEntity> snapshot = await local.readWallSnapshot('u1');
      expect(snapshot.single.pinnedAt, isNull);
    });

    test('a permission error returns an error and rolls the local snapshot back to the old pin', () async {
      final oldPin = DateTime.utc(2026, 4);
      final local = _local();
      await local.updateWallSnapshot('u1', (_) => <FavouriteWallEntity>[prismFav('p1').withPinnedAt(oldPin)]);
      final firestore = _PinWriteFirestore()
        ..updateError = FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
      final repository = FavouriteWallsRepositoryImpl(
        firestore,
        local,
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
      );

      final Result<void> result = await repository.setPinned(userId: 'u1', wall: prismFav('p1').withPinnedAt(oldPin));

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ServerFailure>());
      final List<FavouriteWallEntity> snapshot = await local.readWallSnapshot('u1');
      expect(snapshot.single.pinnedAt, oldPin);
      expect(snapshot.single.syncStatus, FavouriteSyncStatus.synced);
      expect(await local.readFavouriteOperation('u1', 'p1'), isNull);
    });

    test('a timed out pin keeps the optimistic pin without a favourite-add journal entry', () async {
      final DateTime pin = DateTime.utc(2026, 5, 6);
      final FavoritesLocalDataSource local = _local();
      await local.updateWallSnapshot('u1', (_) => <FavouriteWallEntity>[prismFav('p1')]);
      final _PinWriteFirestore firestore = _PinWriteFirestore()..updateError = TimeoutException('offline');
      final FavouriteWallsRepositoryImpl repository = FavouriteWallsRepositoryImpl(
        firestore,
        local,
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
      );

      final Result<void> result = await repository.setPinned(userId: 'u1', wall: prismFav('p1'), pinnedAt: pin);

      expect(result.isSuccess, isTrue);
      expect((await local.readWallSnapshot('u1')).single.pinnedAt, pin);
      expect(await local.readFavouriteOperation('u1', 'p1'), isNull);
    });

    test('pinning a rejected addition keeps its rejected status and updated wall data', () async {
      final DateTime pin = DateTime.utc(2026, 5, 6);
      final FavoritesLocalDataSource local = _local();
      final FavouriteWallEntity wall = prismFav('p1');
      await local.updateWallSnapshot(
        'u1',
        (_) => <FavouriteWallEntity>[wall.withSyncStatus(FavouriteSyncStatus.rejected)],
      );
      final Map<String, Object?> operation = await local.createFavouriteOperation(
        'u1',
        wall.id,
        desired: true,
        wall: Map<String, Object?>.from(favouriteWallToDoc(wall)),
      );
      await local.updateFavouriteOperationStatus(
        'u1',
        wall.id,
        operation['operationId']! as String,
        status: 'rejected',
      );
      final _PinWriteFirestore firestore = _PinWriteFirestore();
      final FavouriteWallsRepositoryImpl repository = FavouriteWallsRepositoryImpl(
        firestore,
        local,
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
      );

      final Result<void> result = await repository.setPinned(userId: 'u1', wall: wall, pinnedAt: pin);

      final Map<String, Object?> updatedOperation = (await local.readFavouriteOperation('u1', 'p1'))!;
      expect(result.isSuccess, isTrue);
      expect(updatedOperation['status'], 'rejected');
      expect(Map<String, Object?>.from(updatedOperation['wall']! as Map)['pinnedAt'], pin.toIso8601String());
      expect(firestore.writes, isEmpty);
      expect((await local.readWallSnapshot('u1')).single.pinnedAt, pin);
    });

    test('pinning a favourite with a pending removal does not replace the removal', () async {
      final FavoritesLocalDataSource local = _local();
      final FavouriteWallEntity wall = prismFav('p1');
      await local.updateWallSnapshot('u1', (_) => <FavouriteWallEntity>[wall]);
      final Map<String, Object?> operation = await local.createFavouriteOperation(
        'u1',
        wall.id,
        desired: false,
        wall: Map<String, Object?>.from(favouriteWallToDoc(wall)),
      );
      final FavouriteWallsRepositoryImpl repository = FavouriteWallsRepositoryImpl(
        _PinWriteFirestore(),
        local,
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
      );

      final Result<void> result = await repository.setPinned(
        userId: 'u1',
        wall: wall,
        pinnedAt: DateTime.utc(2026, 5, 6),
      );

      expect(result.isFailure, isTrue);
      expect(await local.readFavouriteOperation('u1', wall.id), operation);
      expect((await local.readWallSnapshot('u1')).single.pinnedAt, isNull);
    });

    test('a missing server favourite rolls back and is never queued as an add', () async {
      final DateTime pin = DateTime.utc(2026, 5, 6);
      final FavoritesLocalDataSource local = _local();
      await local.updateWallSnapshot('u1', (_) => <FavouriteWallEntity>[prismFav('p1')]);
      final _PinWriteFirestore firestore = _PinWriteFirestore()
        ..updateError = FirebaseException(plugin: 'cloud_firestore', code: 'not-found');
      final FavouriteWallsRepositoryImpl repository = FavouriteWallsRepositoryImpl(
        firestore,
        local,
        unusedGuestStore(),
        EmptyCanonicalWallpaperRepository(),
      );

      final Result<void> result = await repository.setPinned(userId: 'u1', wall: prismFav('p1'), pinnedAt: pin);

      expect(result.isFailure, isTrue);
      expect((await local.readWallSnapshot('u1')).single.pinnedAt, isNull);
      expect(await local.readFavouriteOperation('u1', 'p1'), isNull);
      expect(firestore.writes, isEmpty);
    });

    test('a guest pin writes the doc with pinnedAt to the guest store and never calls Firestore', () async {
      final stamp = DateTime.utc(2026, 10, 29, 9);
      final firestore = _PinWriteFirestore();
      final store = tempGuestStore();
      final repository = FavouriteWallsRepositoryImpl(firestore, _local(), store, EmptyCanonicalWallpaperRepository());

      final Result<void> result = await repository.setPinned(userId: '', wall: pexelsFav('g1'), pinnedAt: stamp);

      expect(result.isSuccess, isTrue, reason: result.failure?.message);
      expect(firestore.writes, isEmpty);
      expect(firestore.sourceTags, isEmpty);
      final Map<String, Map<String, Object?>> saved = await store.readAll();
      expect(saved.keys, <String>['g1']);
      final FavouriteWallEntity stored = mapFavouriteWallDoc(FavouriteWallDocDto.fromJson(saved['g1']!), 'g1');
      expect(stored.pinnedAt, stamp);
    });
  });
}

/// Records the sourceTag of each update and can fail updates, for the pin writes.
class _PinWriteFirestore extends _MetadataFirestore {
  final List<String> sourceTags = <String>[];
  Object? updateError;

  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) {
    sourceTags.add(sourceTag);
    final Object? error = updateError;
    if (error != null) return Future<void>.error(error);
    return super.updateDoc(collection, id, data, sourceTag: sourceTag);
  }
}
