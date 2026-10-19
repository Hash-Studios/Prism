import 'dart:async';
import 'dart:io';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/favourite_walls/data/favourites_sync_service.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_merger.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_store.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';
import '../support/canonical_fixture.dart';
import '../support/guest_store_fixture.dart';
import '../support/merge_firestore.dart';

class _CanonicalRepository extends EmptyCanonicalWallpaperRepository {
  Future<Result<PrismWallpaper?>> Function(String)? lookup;
  final List<String> reads = <String>[];

  @override
  Future<Result<PrismWallpaper?>> fetchCanonicalById(String id) async {
    reads.add(id);
    return lookup == null ? Result.success(null) : await lookup!(id);
  }
}

PrismWallpaper _canonical({List<String> collections = const <String>['premium']}) => PrismWallpaper(
  core: const WallpaperCore(
    id: 'a',
    source: WallpaperSource.prism,
    fullUrl: '',
    thumbnailUrl: 'https://example.com/current-thumb.jpg',
  ),
  collections: collections,
);

class _WatchFirestore extends MergeFirestore {
  Object? writeError;
  Future<void> Function()? beforeWrite;

  @override
  Future<void> setDoc(
    String collection,
    String docId,
    Map<String, dynamic> data, {
    bool merge = false,
    required String sourceTag,
  }) async {
    await beforeWrite?.call();
    if (writeError != null) throw writeError!;
    await super.setDoc(collection, docId, data, merge: merge, sourceTag: sourceTag);
  }

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

  Future<void> Function()? afterNextSnapshotRead;

  @override
  Future<List<FavouriteWallEntity>> readWallSnapshot(String userId) async {
    final afterRead = afterNextSnapshotRead;
    afterNextSnapshotRead = null;
    final snapshot = await super.readWallSnapshot(userId);
    await afterRead?.call();
    return snapshot;
  }

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
  late _CanonicalRepository canonical;
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
    canonical = _CanonicalRepository();
    service = FavouritesSyncService(firestore, local, GuestFavouritesMerger(firestore, guests, local), canonical);
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

  test('live and cached snapshots publish current canonical collections on every update', () async {
    canonical.lookup = (_) async => Result.success(_canonical());
    await service.start('u');
    final saved = <String, Map<String, dynamic>>{
      'a': <String, dynamic>{
        'id': 'a',
        'provider': 'prism',
        'collections': <String>['free'],
        'url': 'https://example.com/saved.jpg',
        'thumb': 'https://example.com/saved-thumb.jpg',
      },
    };
    firestore.emit(saved);
    await waitForUpdateCount(1);
    expect((updates.last.items.single as PrismFavouriteWall).wallpaper.collections, <String>['premium']);
    expect(updates.last.items.single.fullUrl, '');
    firestore.emit(saved, fromCache: true);
    await waitForUpdateCount(2);
    expect((updates.last.items.single as PrismFavouriteWall).wallpaper.collections, <String>['premium']);
    canonical.lookup = (_) async => Result.success(_canonical(collections: <String>['free']));
    firestore.emit(saved);
    await waitForUpdateCount(3);
    expect((updates.last.items.single as PrismFavouriteWall).wallpaper.collections, <String>['free']);
    expect((await local.readWallSnapshot('u')).single.fullUrl, 'https://example.com/saved.jpg');
  });

  for (final outcome in <String>['missing', 'offline', 'throws']) {
    test('$outcome canonical lookup preserves saved reference and metadata', () async {
      canonical.lookup = (_) async {
        if (outcome == 'throws') throw StateError('unavailable');
        return outcome == 'offline' ? Result.error(const NetworkFailure('offline')) : Result.success(null);
      };
      await service.start('u');
      firestore.emit(<String, Map<String, dynamic>>{
        'a': <String, dynamic>{
          'id': 'a',
          'provider': 'prism',
          'collections': <String>['free'],
          'url': 'https://example.com/saved.jpg',
          'thumb': 'https://example.com/saved-thumb.jpg',
          'favouritedAt': DateTime.utc(2026, 1, 2),
        },
      });
      await waitForUpdateCount(1);
      final wall = updates.single.items.single as PrismFavouriteWall;
      expect(wall.id, 'a');
      expect(wall.fullUrl, 'https://example.com/saved.jpg');
      expect(wall.thumbnailUrl, 'https://example.com/saved-thumb.jpg');
      expect(wall.wallpaper.collections, <String>['free']);
      expect(wall.favouritedAt, DateTime.utc(2026, 1, 2));
      expect(wall.syncStatus, FavouriteSyncStatus.synced);
    });
  }

  test('bundled starters and external favourites publish without canonical reads', () async {
    await service.start('u');
    firestore.emit(<String, Map<String, dynamic>>{
      'starter-sunset': <String, dynamic>{'id': 'starter-sunset', 'provider': 'prism'},
      'external': <String, dynamic>{'id': 'external', 'provider': 'pexels', 'url': 'https://example.com/external.jpg'},
    });
    await waitForUpdateCount(1);
    expect(updates.single.items.map((wall) => wall.id), <String>['starter-sunset', 'external']);
    expect(canonical.reads, isEmpty);
  });

  for (final change in <String>['stop', 'switch', 'restart']) {
    test('canonical lookup completed after $change cannot publish or replace latest', () async {
      final started = Completer<void>();
      final pending = Completer<Result<PrismWallpaper?>>();
      canonical.lookup = (_) {
        started.complete();
        return pending.future;
      };
      await service.start('u');
      firestore.emit(<String, Map<String, dynamic>>{
        'a': <String, dynamic>{
          'id': 'a',
          'provider': 'prism',
          'collections': <String>['free'],
        },
      });
      await started.future;
      await service.stop();
      if (change != 'stop') {
        if (change == 'switch') app_state.prismUser.id = 'v';
        await service.start(change == 'switch' ? 'v' : 'u');
        firestore.emit(<String, Map<String, dynamic>>{
          'current': <String, dynamic>{'id': 'current', 'provider': 'pexels'},
        });
        await waitForUpdateCount(1);
      }
      pending.complete(Result.success(_canonical()));
      await Future<void>.delayed(Duration.zero);
      expect(
        updates.map((update) => update.items.map((wall) => wall.id).toList()).toList(),
        change == 'stop'
            ? <List<String>>[]
            : <List<String>>[
                <String>['current'],
              ],
      );
      final late = <FavouritesSyncUpdate>[];
      final sub = service.listen(late.add);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(
        late.map((update) => update.items.map((wall) => wall.id).toList()).toList(),
        change == 'stop'
            ? <List<String>>[]
            : <List<String>>[
                <String>['current'],
              ],
      );
    });
  }

  test('rejected operation publishes canonical collections and retains rejected status', () async {
    canonical.lookup = (_) async => Result.success(_canonical());
    firestore.writeError = FirestoreError(code: 'permission-denied', message: 'denied');
    await local.createFavouriteOperation(
      'u',
      'a',
      desired: true,
      wall: <String, Object?>{
        'id': 'a',
        'provider': 'prism',
        'collections': <String>['free'],
        'url': 'https://example.com/saved.jpg',
        'thumb': 'https://example.com/saved-thumb.jpg',
      },
    );
    await service.start('u');
    await waitForUpdateCount(1);
    final wall = updates.single.items.single as PrismFavouriteWall;
    expect(wall.wallpaper.collections, <String>['premium']);
    expect(wall.fullUrl, '');
    expect(wall.syncStatus, FavouriteSyncStatus.rejected);
    expect((await local.readFavouriteOperation('u', 'a'))!['status'], 'rejected');
  });

  test('rejection racing server preparation preserves remote additions and deletions', () async {
    await service.start('u');
    firestore.emit(<String, Map<String, dynamic>>{
      'c': <String, dynamic>{'id': 'c', 'provider': 'pexels'},
    });
    await waitForUpdateCount(1);
    updates.clear();
    final writeGate = Completer<void>();
    firestore.beforeWrite = () => writeGate.future;
    firestore.writeError = FirestoreError(code: 'permission-denied', message: 'denied');
    await local.createFavouriteOperation(
      'u',
      'a',
      desired: true,
      wall: <String, Object?>{'id': 'a', 'provider': 'pexels'},
    );
    await service.start('u');
    final readStarted = Completer<void>();
    final readGate = Completer<void>();
    local.afterNextSnapshotRead = () {
      readStarted.complete();
      return readGate.future;
    };
    firestore.emit(<String, Map<String, dynamic>>{
      'b': <String, dynamic>{'id': 'b', 'provider': 'pexels'},
    });
    await readStarted.future;
    writeGate.complete();
    await local.waitForStatus('a', 'rejected');
    await Future<void>.delayed(Duration.zero);
    readGate.complete();
    await waitForUpdateCount(1);
    expect(updates.last.items.map((wall) => wall.id), unorderedEquals(<String>['a', 'b']));
    expect((await local.readWallSnapshot('u')).map((wall) => wall.id), unorderedEquals(<String>['a', 'b']));
    expect(local.isWallFavourite('u', 'b'), isTrue);
    expect(local.isWallFavourite('u', 'c'), isFalse);
    expect(updates.last.items.singleWhere((wall) => wall.id == 'a').syncStatus, FavouriteSyncStatus.rejected);
  });

  for (final olderPublication in <String>['snapshot', 'status']) {
    test('older $olderPublication hydration cannot replace newer rejected canonical update', () async {
      final writeGate = Completer<void>();
      final lookupStarted = Completer<void>();
      final olderLookup = Completer<Result<PrismWallpaper?>>();
      firestore.beforeWrite = () => writeGate.future;
      firestore.writeError = FirestoreError(code: 'permission-denied', message: 'denied');
      var reads = 0;
      canonical.lookup = (_) {
        if (++reads == 1) {
          lookupStarted.complete();
          return olderLookup.future;
        }
        return Future.value(Result.success(_canonical()));
      };
      final saved = <String, dynamic>{
        'id': 'a',
        'provider': 'prism',
        'collections': <String>['free'],
        'url': 'https://example.com/saved.jpg',
        'thumb': 'https://example.com/saved-thumb.jpg',
      };
      await local.createFavouriteOperation('u', 'a', desired: true, wall: saved);
      await service.start('u');
      if (olderPublication == 'snapshot') {
        firestore.emit(<String, Map<String, dynamic>>{'a': saved});
        await lookupStarted.future;
        writeGate.complete();
      } else {
        writeGate.complete();
        await lookupStarted.future;
        firestore.emit(<String, Map<String, dynamic>>{'a': saved});
      }
      await waitForUpdateCount(1);
      expect((updates.single.items.single as PrismFavouriteWall).wallpaper.collections, <String>['premium']);
      expect(updates.single.items.single.syncStatus, FavouriteSyncStatus.rejected);
      olderLookup.complete(Result.success(_canonical(collections: <String>['free'])));
      await Future<void>.delayed(Duration.zero);
      expect(updates, hasLength(1));
      final latest = Completer<FavouritesSyncUpdate>();
      final subscription = service.listen(latest.complete);
      final replay = await latest.future;
      await subscription.cancel();
      expect((replay.items.single as PrismFavouriteWall).wallpaper.collections, <String>['premium']);
      expect(replay.items.single.syncStatus, FavouriteSyncStatus.rejected);
    });
  }

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
