import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/favourite_walls/data/favourites_sync_service.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_merger.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';
import '../support/guest_store_fixture.dart';
import '../support/merge_firestore.dart';

class _WatchFirestore extends MergeFirestore {
  final List<FirestoreQuerySpec> watched = <FirestoreQuerySpec>[];
  final List<void Function(Map<String, Map<String, dynamic>> docs, bool fromCache)> emitters = [];
  int cancelled = 0;

  @override
  Stream<({List<T> items, bool isFromCache})> watchQueryWithMetadata<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  ) {
    watched.add(spec);
    final StreamController<({List<T> items, bool isFromCache})> controller =
        StreamController<({List<T> items, bool isFromCache})>(onCancel: () => cancelled++);
    emitters.add((docs, fromCache) {
      controller.add((items: docs.entries.map((e) => map(e.value, e.key)).toList(), isFromCache: fromCache));
    });
    return controller.stream;
  }

  void emit(Map<String, Map<String, dynamic>> docs, {bool fromCache = false}) => emitters.last(docs, fromCache);
}

void main() {
  late _WatchFirestore firestore;
  late FavoritesLocalDataSource local;
  late GuestFavouritesStore guests;
  late FavouritesSyncService service;
  late List<FavouritesSyncUpdate> updates;

  setUp(() {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'u'
      ..loggedIn = true;
    firestore = _WatchFirestore();
    local = FavoritesLocalDataSource(InMemoryLocalStore());
    guests = tempGuestStore();
    service = FavouritesSyncService(firestore, local, GuestFavouritesMerger(firestore, guests, local));
    updates = <FavouritesSyncUpdate>[];
    service.listen(updates.add);
  });

  tearDown(() async {
    await service.stop();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

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
    await settle();

    expect(updates.single.userId, 'u');
    expect(updates.single.items.map((wall) => wall.id), <String>['a', 'b']);
    expect(local.isWallFavourite('u', 'stale'), isFalse);
    expect(local.isWallFavourite('u', 'a'), isTrue);
  });

  test('an empty snapshot from the cache is ignored, an empty one from the server is trusted', () async {
    await local.setWallFavourite('u', 'a', true);
    await service.start('u');

    firestore.emit(const <String, Map<String, dynamic>>{}, fromCache: true);
    await settle();

    expect(updates, isEmpty);
    expect(local.isWallFavourite('u', 'a'), isTrue, reason: 'a cold cache must not wipe the hearts');

    firestore.emit(const <String, Map<String, dynamic>>{});
    await settle();

    expect(updates.single.items, isEmpty);
    expect(local.isWallFavourite('u', 'a'), isFalse);
  });

  test('a non-empty snapshot from the cache is applied', () async {
    await service.start('u');

    firestore.emit(<String, Map<String, dynamic>>{
      'a': <String, dynamic>{'id': 'a', 'provider': 'prism'},
    }, fromCache: true);
    await settle();

    expect(updates.single.items.single.id, 'a');
  });

  test('a late listener gets the latest update at once', () async {
    await service.start('u');
    firestore.emit(<String, Map<String, dynamic>>{
      'a': <String, dynamic>{'id': 'a', 'provider': 'prism'},
    });
    await settle();
    final List<FavouritesSyncUpdate> late = <FavouritesSyncUpdate>[];

    final sub = service.listen(late.add);
    await settle();
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
    await settle();

    await service.stop();
    final List<FavouritesSyncUpdate> late = <FavouritesSyncUpdate>[];
    final sub = service.listen(late.add);
    await settle();
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
    await settle();
    await settle();

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

  test('a failed guest merge does not stop the sync and keeps the guest list', () async {
    await guests.put('g1', <String, dynamic>{'id': 'g1', 'provider': 'pexels'});
    firestore.batchError = StateError('offline');

    await service.start('u');

    expect(firestore.watched, hasLength(1));
    expect((await guests.readAll()).keys, <String>['g1']);
  });
}
