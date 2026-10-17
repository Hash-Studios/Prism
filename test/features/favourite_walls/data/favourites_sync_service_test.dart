import 'dart:async';
import 'dart:io';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/favourite_walls/data/favourites_sync_service.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_merger.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import '../../../support/in_memory_local_store.dart';
import '../support/guest_store_fixture.dart';
import '../support/merge_firestore.dart';

class _WatchFirestore extends MergeFirestore {
  final List<FirestoreQuerySpec> watched = <FirestoreQuerySpec>[];
  final List<void Function(Map<String, Map<String, dynamic>> docs, bool fromCache)> emitters = [];
  Completer<void> _cancelledSignal = Completer<void>();
  int cancelled = 0;

  @override
  Stream<({List<T> items, bool isFromCache})> watchQueryWithMetadata<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  ) {
    watched.add(spec);
    final StreamController<({List<T> items, bool isFromCache})> controller =
        StreamController<({List<T> items, bool isFromCache})>(
          onCancel: () {
            cancelled++;
            if (!_cancelledSignal.isCompleted) _cancelledSignal.complete();
          },
          sync: true,
        );
    emitters.add((docs, fromCache) {
      controller.add((items: docs.entries.map((e) => map(e.value, e.key)).toList(), isFromCache: fromCache));
    });
    return controller.stream;
  }

  void emit(Map<String, Map<String, dynamic>> docs, {bool fromCache = false}) => emitters.last(docs, fromCache);

  Future<void> waitForCancellation(int count) async {
    while (cancelled < count) {
      final signal = _cancelledSignal.future;
      await signal;
      _cancelledSignal = Completer<void>();
    }
  }
}

class _RecordingFavoritesLocalDataSource extends FavoritesLocalDataSource {
  _RecordingFavoritesLocalDataSource(super.store);

  final List<({String wallId, String status, bool changed})> statusUpdates =
      <({String wallId, String status, bool changed})>[];
  Completer<void> _statusSignal = Completer<void>();
  int activeOperationReads = 0;
  Completer<void> _operationReadsDrained = Completer<void>()..complete();

  @override
  Future<Map<String, Map<String, Object?>>> readFavouriteOperations(String userId) async {
    activeOperationReads++;
    if (activeOperationReads == 1) _operationReadsDrained = Completer<void>();
    try {
      return await super.readFavouriteOperations(userId);
    } finally {
      activeOperationReads--;
      if (activeOperationReads == 0 && !_operationReadsDrained.isCompleted) _operationReadsDrained.complete();
    }
  }

  Future<void> waitForOperationReadsToDrain() async {
    while (activeOperationReads > 0) {
      await _operationReadsDrained.future;
    }
  }

  @override
  Future<bool> updateFavouriteOperationStatus(
    String userId,
    String wallId,
    String operationId, {
    required String status,
    String? error,
  }) async {
    final bool changed = await super.updateFavouriteOperationStatus(
      userId,
      wallId,
      operationId,
      status: status,
      error: error,
    );
    statusUpdates.add((wallId: wallId, status: status, changed: changed));
    if (!_statusSignal.isCompleted) _statusSignal.complete();
    return changed;
  }

  Future<void> waitForStatus(String wallId, String status) async {
    while (!statusUpdates.any((update) => update.wallId == wallId && update.status == status && update.changed)) {
      final signal = _statusSignal.future;
      await signal;
      _statusSignal = Completer<void>();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (_) async => Directory.systemTemp.path,
  );
  late _WatchFirestore firestore;
  late _RecordingFavoritesLocalDataSource local;
  late GuestFavouritesStore guests;
  late FavouritesSyncService service;
  late List<FavouritesSyncUpdate> updates;
  Completer<void> updateSignal = Completer<void>();

  setUp(() {
    updateSignal = Completer<void>();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'u'
      ..loggedIn = true;
    firestore = _WatchFirestore();
    local = _RecordingFavoritesLocalDataSource(InMemoryLocalStore());
    guests = tempGuestStore();
    service = FavouritesSyncService(firestore, local, GuestFavouritesMerger(firestore, guests, local));
    addTearDown(() async {
      await service.stop();
      await local.waitForOperationReadsToDrain();
    });
    updates = <FavouritesSyncUpdate>[];
    service.listen((update) {
      updates.add(update);
      if (!updateSignal.isCompleted) updateSignal.complete();
    });
  });

  tearDown(() async {
    await service.stop();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  Future<void> waitForUpdateCount(int count) async {
    while (updates.length < count) {
      final signal = updateSignal.future;
      await signal;
      updateSignal = Completer<void>();
    }
  }

  test('watches the signed-in user images with the sync source tag', () async {
    await service.start('u');

    expect(firestore.watched.single.collection, 'usersv2/u/images');
    expect(firestore.watched.single.sourceTag, 'favourite_walls.watch');
    expect(firestore.watched.single.isStream, isTrue);
  });

  test('a server snapshot replaces the heart set and publishes the walls', () async {
    await local.setWallFavourite('u', 'stale', true);
    await service.start('u');

    firestore.emit(<String, Map<String, dynamic>>{
      'a': <String, dynamic>{'id': 'a', 'provider': 'prism'},
      'b': <String, dynamic>{'id': 'b', 'provider': 'pexels'},
    });
    await waitForUpdateCount(1);

    expect(updates.single.userId, 'u');
    expect(updates.single.items.map((wall) => wall.id), <String>['a', 'b']);
    expect(local.isWallFavourite('u', 'stale'), isFalse);
    expect(local.isWallFavourite('u', 'a'), isTrue);
  });

  test('an empty snapshot from the cache is ignored, an empty one from the server is trusted', () async {
    await local.setWallFavourite('u', 'a', true);
    await service.start('u');

    firestore.emit(const <String, Map<String, dynamic>>{}, fromCache: true);
    expect(updates, isEmpty);
    expect(local.isWallFavourite('u', 'a'), isTrue, reason: 'a cold cache must not wipe the hearts');

    firestore.emit(const <String, Map<String, dynamic>>{});
    await waitForUpdateCount(1);

    expect(updates.single.items, isEmpty);
    expect(local.isWallFavourite('u', 'a'), isFalse);
  });

  test('a non-empty snapshot from the cache is applied', () async {
    await service.start('u');

    firestore.emit(<String, Map<String, dynamic>>{
      'a': <String, dynamic>{'id': 'a', 'provider': 'prism'},
    }, fromCache: true);
    await waitForUpdateCount(1);

    expect(updates.single.items.single.id, 'a');
  });

  test('a late listener gets the latest update at once', () async {
    await service.start('u');
    firestore.emit(<String, Map<String, dynamic>>{
      'a': <String, dynamic>{'id': 'a', 'provider': 'prism'},
    });
    await waitForUpdateCount(1);
    final List<FavouritesSyncUpdate> late = <FavouritesSyncUpdate>[];
    final Completer<void> lateUpdate = Completer<void>();

    final sub = service.listen((update) {
      late.add(update);
      if (!lateUpdate.isCompleted) lateUpdate.complete();
    });
    await lateUpdate.future;
    await sub.cancel();

    expect(late.single.items.single.id, 'a');
  });

  test('starting again for the same user keeps one listener', () async {
    await service.start('u');
    await service.start('u');

    expect(firestore.watched, hasLength(1));
  });

  test('stop cancels the listener and forgets the last update', () async {
    await service.start('u');
    firestore.emit(<String, Map<String, dynamic>>{
      'a': <String, dynamic>{'id': 'a', 'provider': 'prism'},
    });
    await waitForUpdateCount(1);

    await service.stop();
    final List<FavouritesSyncUpdate> late = <FavouritesSyncUpdate>[];
    final sub = service.listen(late.add);
    await sub.cancel();

    expect(firestore.cancelled, 1);
    expect(late, isEmpty);
  });

  test('a snapshot that arrives after the user changed stops the listener and changes nothing', () async {
    await service.start('u');
    app_state.prismUser = app_constants.createGuestPrismUser();

    firestore.emit(<String, Map<String, dynamic>>{
      'a': <String, dynamic>{'id': 'a', 'provider': 'prism'},
    });
    await firestore.waitForCancellation(1);

    expect(updates, isEmpty);
    expect(local.isWallFavourite('u', 'a'), isFalse);
    expect(firestore.cancelled, 1);
  });

  test('starting with a blank user id stops the sync', () async {
    await service.start('u');

    await service.start(' ');

    expect(firestore.cancelled, 1);
  });

  test('starting for an account also merges the guest favourites', () async {
    await guests.put('g1', <String, dynamic>{'id': 'g1', 'provider': 'pexels'});

    await service.start('u');

    expect(firestore.batches.single.sets.single.id, 'g1');
    expect(await guests.readAll(), isEmpty);
  });

  test('replayed favourite operations restore known date fields before Firestore writes', () async {
    final operation = await local.createFavouriteOperation(
      'u',
      'replayed',
      desired: true,
      wall: <String, Object?>{
        'id': 'replayed',
        'provider': 'Prism',
        'url': 'https://img.test/full.jpg',
        'thumb': 'https://img.test/thumb.jpg',
        'createdAt': '2026-01-02T03:04:05.000Z',
        'favouritedAt': '2026-02-03T04:05:06.000Z',
      },
    );

    await service.start('u');
    await local.waitForStatus('replayed', 'synced');

    expect(firestore.writes.single.data!['createdAt'], DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(firestore.writes.single.data!['favouritedAt'], DateTime.utc(2026, 2, 3, 4, 5, 6));
    expect((await local.readFavouriteOperation('u', 'replayed'))!['status'], 'synced');
    expect(operation['status'], 'pending');
  });

  test('a previously queued bundled starter is never replayed to Firestore', () async {
    await local.createFavouriteOperation(
      'u',
      'starter-sunset',
      desired: true,
      wall: <String, Object?>{
        'id': 'starter-sunset',
        'provider': 'Prism',
        'url': '/tmp/untrusted-starter-path.jpg',
        'thumb': '/tmp/untrusted-starter-path.jpg',
      },
    );

    await service.start('u');
    await local.waitForStatus('starter-sunset', 'synced');

    expect(firestore.writes, isEmpty);
    expect((await local.readFavouriteOperation('u', 'starter-sunset'))!['status'], 'synced');
  });

  test('a failed guest merge does not stop the sync and keeps the guest list', () async {
    await guests.put('g1', <String, dynamic>{'id': 'g1', 'provider': 'pexels'});
    firestore.batchError = StateError('offline');

    await service.start('u');

    expect(firestore.watched, hasLength(1));
    expect((await guests.readAll()).keys, <String>['g1']);
  });
}
