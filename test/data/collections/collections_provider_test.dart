import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart';
import 'package:Prism/data/offline/offline_snapshot_codec.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_feed_cache_local_data_source.dart';
import '../../support/fake_firestore_client.dart';
import '../../support/fake_user_block_repository.dart';

class _ThrowingFeedCache extends FakeFeedCacheLocalDataSource {
  @override
  Future<void> write({
    required String source,
    required String scope,
    required Object? payload,
    required int ttlHours,
  }) => Future<void>.error(StateError('cache unavailable'));
}

class _HangingFirestoreClient extends FakeFirestoreClient {
  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) =>
      Completer<List<T>>().future;
}

class _PendingBlockRepository extends FakeUserBlockRepository {
  _PendingBlockRepository() : super.pending();

  final Completer<void> requested = Completer<void>();

  @override
  Future<Set<String>> getBlockedCreatorUids({bool waitForInitialLoad = false}) {
    if (waitForInitialLoad && !requested.isCompleted) requested.complete();
    return super.getBlockedCreatorUids(waitForInitialLoad: waitForInitialLoad);
  }
}

class _GatedCache extends FakeFeedCacheLocalDataSource {
  String? gatedScope;
  final Completer<void> readStarted = Completer<void>();
  final Completer<void> readGate = Completer<void>();

  @override
  Future<FeedSnapshot?> read({required String source, required String scope}) async {
    final snapshot = snapshots['$source/$scope'];
    if (scope == gatedScope && !readStarted.isCompleted) {
      readStarted.complete();
      await readGate.future;
    }
    return snapshot;
  }
}

class _FirstFilterGated extends FakeUserBlockRepository {
  _FirstFilterGated() : super.pending();

  final Completer<void> started = Completer<void>();
  final Completer<Set<String>> gate = Completer<Set<String>>();

  @override
  Future<Set<String>> getBlockedCreatorUids({bool waitForInitialLoad = false}) {
    if (!started.isCompleted) {
      started.complete();
      return gate.future;
    }
    return Future<Set<String>>.value(<String>{});
  }
}

class _FirstQueryGated extends FakeFirestoreClient {
  final Completer<void> started = Completer<void>();
  final Completer<List<FakeDocRow>> gate = Completer<List<FakeDocRow>>();

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic>, String) map) async {
    if (started.isCompleted) return super.query(spec, map);
    querySpecs.add(spec);
    started.complete();
    return (await gate.future).map((row) => map(row.data, row.id)).toList();
  }
}

FeedSnapshot _savedWalls(String id, {bool hasMore = true}) => FeedSnapshot(
  payload: OfflineSnapshotCodec.encodeCollectionWalls(
    items: <Map<String, dynamic>>[_wall(id)],
    lastDocId: '$id-doc',
    hasMore: hasMore,
  ),
  cachedAtUtc: DateTime.now().toUtc(),
  ttlHours: 24,
);

Map<String, dynamic> _wall(String id) => <String, dynamic>{'id': id, 'creatorUid': id};

void main() {
  late FakeFirestoreClient firestore;

  setUp(() {
    collections = <Map<String, dynamic>>[];
    anyCollectionWalls = <Map<String, dynamic>>[];
    firestore = FakeFirestoreClient();
    getIt.registerSingleton<FirestoreClient>(firestore);
    getIt.registerSingleton<FeedCacheLocalDataSource>(FakeFeedCacheLocalDataSource());
    getIt.registerSingleton<UserBlockRepository>(FakeUserBlockRepository.pending()..completeInitial(<String>{}));
  });

  tearDown(() async {
    collections = <Map<String, dynamic>>[];
    anyCollectionWalls = <Map<String, dynamic>>[];
    await getIt.reset();
  });

  group('getCollections', () {
    test('a delayed old index cache cannot replace a newer index or start another query', () async {
      final cache = _GatedCache()..gatedScope = 'index';
      cache.snapshots['collections/index'] = FeedSnapshot(
        payload: OfflineSnapshotCodec.encodeCollectionIndex(<Map<String, dynamic>>[
          <String, dynamic>{'name': 'old'},
        ]),
        cachedAtUtc: DateTime.now().toUtc(),
        ttlHours: 24,
      );
      await getIt.unregister<FeedCacheLocalDataSource>();
      getIt.registerSingleton<FeedCacheLocalDataSource>(cache);
      final first = getCollections();
      await cache.readStarted.future;
      firestore.onQuery = (_) => <FakeDocRow>[
        (id: 'new', data: <String, dynamic>{'name': 'new'}),
      ];
      await getCollections();
      cache.readGate.complete();
      await first;

      expect(collections.single['name'], 'new');
      expect(firestore.querySpecs, hasLength(1));
      expect(OfflineSnapshotCodec.decodeCollectionIndex(cache.snapshots['collections/index']).single['name'], 'new');
    });

    test('successful empty index replaces and persists a warm index for an offline reopen', () async {
      firestore.onQuery = (_) => <FakeDocRow>[
        (id: 'old', data: <String, dynamic>{'name': 'old'}),
      ];
      await getCollections();
      firestore.onQuery = (_) => <FakeDocRow>[];

      await getCollections();

      expect(collections, isEmpty);
      final cache = getIt<FeedCacheLocalDataSource>();
      expect(
        OfflineSnapshotCodec.decodeCollectionIndex(await cache.read(source: 'collections', scope: 'index')),
        isEmpty,
      );
      collections = <Map<String, dynamic>>[];
      firestore.queryError = StateError('offline');
      await getCollections();
      expect(collections, isEmpty);
    });

    test('an older index query cannot replace a newer index', () async {
      final remote = _FirstQueryGated();
      await getIt.unregister<FirestoreClient>();
      getIt.registerSingleton<FirestoreClient>(remote);
      final first = getCollections();
      await remote.started.future;
      remote.onQuery = (_) => <FakeDocRow>[
        (id: 'new', data: <String, dynamic>{'name': 'new'}),
      ];
      await getCollections();
      remote.gate.complete(<FakeDocRow>[
        (id: 'old', data: <String, dynamic>{'name': 'old'}),
      ]);
      await first;

      expect(collections.single['name'], 'new');
      final snapshot = await getIt<FeedCacheLocalDataSource>().read(source: 'collections', scope: 'index');
      expect(OfflineSnapshotCodec.decodeCollectionIndex(snapshot).single['name'], 'new');
    });

    test('replaces the list once the query succeeds', () async {
      firestore.onQuery = (_) => <FakeDocRow>[
        (id: 'c1', data: <String, dynamic>{'name': 'space'}),
      ];

      await getCollections();

      expect(collections.map((row) => row['name']), <String>['space']);
    });

    test('keeps the list on screen when the query throws', () async {
      collections = <Map<String, dynamic>>[
        <String, dynamic>{'name': 'old'},
      ];
      firestore.queryError = StateError('permission-denied');

      await getCollections();

      expect(collections.map((row) => row['name']), <String>['old']);
    });

    test('keeps a successful remote list when cache persistence fails', () async {
      await getIt.unregister<FeedCacheLocalDataSource>();
      getIt.registerSingleton<FeedCacheLocalDataSource>(_ThrowingFeedCache());
      firestore.onQuery = (_) => <FakeDocRow>[
        (id: 'c1', data: <String, dynamic>{'name': 'space'}),
      ];

      await getCollections();

      expect(collections.map((row) => row['name']), <String>['space']);
    });

    test('returns cached collections when the remote query never completes', () async {
      final FakeFeedCacheLocalDataSource cache = FakeFeedCacheLocalDataSource();
      cache.snapshots['collections/index'] = FeedSnapshot(
        payload: OfflineSnapshotCodec.encodeCollectionIndex(<Map<String, dynamic>>[
          <String, dynamic>{'name': 'saved'},
        ]),
        cachedAtUtc: DateTime.now().toUtc(),
        ttlHours: 24,
      );
      await getIt.unregister<FeedCacheLocalDataSource>();
      getIt.registerSingleton<FeedCacheLocalDataSource>(cache);
      await getIt.unregister<FirestoreClient>();
      getIt.registerSingleton<FirestoreClient>(_HangingFirestoreClient());

      await getCollections();

      expect(collections.map((row) => row['name']), <String>['saved']);
    });
  });

  group('refreshCollectionWithName', () {
    Future<void> openCollection() async {
      firestore.onQuery = (_) => <FakeDocRow>[(id: 'd1', data: _wall('one'))];
      await getCollectionWithName('space');
      expect(anyCollectionWalls.map((wall) => wall['id']), <String>['one']);
    }

    test('swaps in the fresh walls', () async {
      await openCollection();
      firestore.onQuery = (_) => <FakeDocRow>[(id: 'd2', data: _wall('two'))];

      await refreshCollectionWithName();

      expect(anyCollectionWalls.map((wall) => wall['id']), <String>['two']);
    });

    test('successful empty replacement clears cached walls, cursor and pagination through offline reopen', () async {
      await openCollection();
      firestore.onQuery = (_) => <FakeDocRow>[];

      await refreshCollectionWithName();

      expect(anyCollectionWalls, isEmpty);
      expect(collectionHasMore, isFalse);
      final cache = getIt<FeedCacheLocalDataSource>();
      final saved = OfflineSnapshotCodec.decodeCollectionWalls(
        await cache.read(source: 'collections', scope: 'walls.space'),
      )!;
      expect(saved.items, isEmpty);
      expect(saved.lastDocId, isNull);
      expect(saved.hasMore, isFalse);
      firestore.queryError = StateError('offline');
      await getCollectionWithName('space');
      expect(anyCollectionWalls, isEmpty);
      expect(collectionHasMore, isFalse);
      final queryCount = firestore.querySpecs.length;
      await seeMoreCollectionWithName();
      expect(firestore.querySpecs, hasLength(queryCount));
    });

    test('a delayed A cache cannot replace B or launch another query', () async {
      final cache = _GatedCache()..gatedScope = 'walls.a';
      cache.snapshots['collections/walls.a'] = _savedWalls('old-a');
      await getIt.unregister<FeedCacheLocalDataSource>();
      getIt.registerSingleton<FeedCacheLocalDataSource>(cache);
      final a = getCollectionWithName('a');
      await cache.readStarted.future;
      firestore.onQuery = (_) => <FakeDocRow>[(id: 'b-doc', data: _wall('b'))];
      await getCollectionWithName('b');
      cache.readGate.complete();
      await a;

      expect(anyCollectionWalls.single['id'], 'b');
      expect(collectionHasMore, isFalse);
      expect(firestore.querySpecs, hasLength(1));
      expect(
        OfflineSnapshotCodec.decodeCollectionWalls(cache.snapshots['collections/walls.a'])!.items.single['id'],
        'old-a',
      );
      expect(OfflineSnapshotCodec.decodeCollectionWalls(cache.snapshots['collections/walls.b'])!.lastDocId, 'b-doc');
    });

    for (final bool cached in <bool>[false, true]) {
      test('a delayed ${cached ? 'cached' : 'remote'} A filter cannot commit into B', () async {
        final cache = getIt<FeedCacheLocalDataSource>() as FakeFeedCacheLocalDataSource;
        if (cached) cache.snapshots['collections/walls.a'] = _savedWalls('saved-a');
        final blocks = _FirstFilterGated();
        await getIt.unregister<UserBlockRepository>();
        getIt.registerSingleton<UserBlockRepository>(blocks);
        firestore.onQuery = (_) => <FakeDocRow>[(id: 'a-doc', data: _wall('a'))];
        final a = getCollectionWithName('a');
        await blocks.started.future;
        firestore.onQuery = (_) => List<FakeDocRow>.generate(24, (i) => (id: 'b-$i', data: _wall('b-$i')));
        await getCollectionWithName('b');
        blocks.gate.complete(<String>{});
        await a;

        expect(firestore.querySpecs, hasLength(cached ? 1 : 2));
        expect(anyCollectionWalls.map((wall) => wall['id']), List<String>.generate(24, (i) => 'b-$i'));
        expect(collectionHasMore, isTrue);
        final savedB = OfflineSnapshotCodec.decodeCollectionWalls(cache.snapshots['collections/walls.b'])!;
        expect(savedB.items, hasLength(24));
        expect(savedB.lastDocId, 'b-23');
        expect(savedB.hasMore, isTrue);
        if (cached) {
          expect(
            OfflineSnapshotCodec.decodeCollectionWalls(cache.snapshots['collections/walls.a'])!.items.single['id'],
            'saved-a',
          );
        } else {
          expect(cache.snapshots['collections/walls.a'], isNull);
        }
        firestore.onQuery = (_) => <FakeDocRow>[];
        await seeMoreCollectionWithName();
        expect(firestore.querySpecs.last.startAfterDocId, 'b-23');
      });
    }

    test('A to B to A rejects the original A query by generation', () async {
      final remote = _FirstQueryGated();
      await getIt.unregister<FirestoreClient>();
      getIt.registerSingleton<FirestoreClient>(remote);
      final oldA = getCollectionWithName('a');
      await remote.started.future;
      remote.onQuery = (_) => <FakeDocRow>[(id: 'b-doc', data: _wall('b'))];
      await getCollectionWithName('b');
      remote.onQuery = (_) => <FakeDocRow>[(id: 'new-a-doc', data: _wall('new-a'))];
      await getCollectionWithName('a');
      remote.gate.complete(<FakeDocRow>[(id: 'old-a-doc', data: _wall('old-a'))]);
      await oldA;

      expect(anyCollectionWalls.single['id'], 'new-a');
      final snapshot = await getIt<FeedCacheLocalDataSource>().read(source: 'collections', scope: 'walls.a');
      expect(OfflineSnapshotCodec.decodeCollectionWalls(snapshot)!.lastDocId, 'new-a-doc');
    });

    test('a refresh supersedes an older page waiting for the block filter without partial state changes', () async {
      firestore.onQuery = (_) => List<FakeDocRow>.generate(24, (i) => (id: 'old-$i', data: _wall('old-$i')));
      await getCollectionWithName('a');
      final blocks = _FirstFilterGated();
      await getIt.unregister<UserBlockRepository>();
      getIt.registerSingleton<UserBlockRepository>(blocks);
      firestore.onQuery = (_) => <FakeDocRow>[(id: 'page-doc', data: _wall('page'))];
      final page = seeMoreCollectionWithName();
      await blocks.started.future;
      expect(anyCollectionWalls, hasLength(24));
      expect(collectionHasMore, isTrue);
      firestore.onQuery = (_) => <FakeDocRow>[(id: 'fresh-doc', data: _wall('fresh'))];
      await refreshCollectionWithName();
      blocks.gate.complete(<String>{});
      await page;

      expect(anyCollectionWalls.single['id'], 'fresh');
      expect(collectionHasMore, isFalse);
      final snapshot = await getIt<FeedCacheLocalDataSource>().read(source: 'collections', scope: 'walls.a');
      final saved = OfflineSnapshotCodec.decodeCollectionWalls(snapshot)!;
      expect(saved.items.single['id'], 'fresh');
      expect(saved.lastDocId, 'fresh-doc');
      expect(saved.hasMore, isFalse);
    });

    test('load more during refresh cannot use the old cursor or supersede the replacement', () async {
      firestore.onQuery = (_) => List<FakeDocRow>.generate(24, (i) => (id: 'old-$i', data: _wall('old-$i')));
      await getCollectionWithName('a');
      final remote = _FirstQueryGated()
        ..onQuery = (_) => <FakeDocRow>[(id: 'stale-page-doc', data: _wall('stale-page'))];
      await getIt.unregister<FirestoreClient>();
      getIt.registerSingleton<FirestoreClient>(remote);

      final refresh = refreshCollectionWithName();
      await remote.started.future;
      await seeMoreCollectionWithName();
      remote.gate.complete(<FakeDocRow>[(id: 'fresh-doc', data: _wall('fresh'))]);
      await refresh;

      expect(remote.querySpecs, hasLength(1));
      expect(remote.querySpecs.single.startAfterDocId, isNull);
      expect(anyCollectionWalls.single['id'], 'fresh');
      expect(collectionHasMore, isFalse);
      final snapshot = await getIt<FeedCacheLocalDataSource>().read(source: 'collections', scope: 'walls.a');
      final saved = OfflineSnapshotCodec.decodeCollectionWalls(snapshot)!;
      expect(saved.items.single['id'], 'fresh');
      expect(saved.lastDocId, 'fresh-doc');
    });

    test('a duplicate load more call does not invalidate the pending page', () async {
      firestore.onQuery = (_) => List<FakeDocRow>.generate(24, (i) => (id: 'old-$i', data: _wall('old-$i')));
      await getCollectionWithName('a');
      final remote = _FirstQueryGated()..onQuery = (_) => <FakeDocRow>[];
      await getIt.unregister<FirestoreClient>();
      getIt.registerSingleton<FirestoreClient>(remote);

      final page = seeMoreCollectionWithName();
      await remote.started.future;
      await seeMoreCollectionWithName();
      remote.gate.complete(<FakeDocRow>[(id: 'next-doc', data: _wall('next'))]);
      await page;

      expect(remote.querySpecs, hasLength(1));
      expect(remote.querySpecs.single.startAfterDocId, 'old-23');
      expect(anyCollectionWalls, hasLength(25));
      expect(anyCollectionWalls.last['id'], 'next');
      expect(collectionHasMore, isFalse);
    });

    test('load more cannot use the previous collection cursor while an initial cache read is pending', () async {
      firestore.onQuery = (_) => List<FakeDocRow>.generate(24, (i) => (id: 'old-$i', data: _wall('old-$i')));
      await getCollectionWithName('a');
      final cache = _GatedCache()..gatedScope = 'walls.b';
      await getIt.unregister<FeedCacheLocalDataSource>();
      getIt.registerSingleton<FeedCacheLocalDataSource>(cache);
      final queryCount = firestore.querySpecs.length;
      firestore.onQuery = (_) => <FakeDocRow>[(id: 'b-doc', data: _wall('b'))];

      final opening = getCollectionWithName('b');
      await cache.readStarted.future;
      await seeMoreCollectionWithName();
      cache.readGate.complete();
      await opening;

      expect(firestore.querySpecs, hasLength(queryCount + 1));
      expect(firestore.querySpecs.last.startAfterDocId, isNull);
      expect(anyCollectionWalls.single['id'], 'b');
    });

    test('persisted collection snapshots are detached from mutable displayed maps', () async {
      firestore.onQuery = (_) => <FakeDocRow>[
        (
          id: 'c',
          data: <String, dynamic>{
            'name': 'old',
            'details': <String, Object?>{'label': 'saved'},
          },
        ),
      ];
      await getCollections();
      (collections.single['details'] as Map<String, Object?>)['label'] = 'changed';
      firestore.onQuery = (_) => <FakeDocRow>[
        (
          id: 'w',
          data: <String, dynamic>{
            ..._wall('wall'),
            'details': <String, Object?>{'label': 'saved'},
          },
        ),
      ];
      await getCollectionWithName('a');
      (anyCollectionWalls.single['details'] as Map<String, Object?>)['label'] = 'changed';

      final cache = getIt<FeedCacheLocalDataSource>();
      final index = OfflineSnapshotCodec.decodeCollectionIndex(await cache.read(source: 'collections', scope: 'index'));
      final walls = OfflineSnapshotCodec.decodeCollectionWalls(
        await cache.read(source: 'collections', scope: 'walls.a'),
      )!;
      expect((index.single['details'] as Map<String, Object?>)['label'], 'saved');
      expect((walls.items.single['details'] as Map<String, Object?>)['label'], 'saved');
    });

    test('keeps the walls on screen when the reload fails', () async {
      await openCollection();
      firestore.queryError = StateError('offline');

      await refreshCollectionWithName();

      expect(anyCollectionWalls.map((wall) => wall['id']), <String>['one']);
    });

    test('restores a saved collection before a new offline open', () async {
      await openCollection();
      firestore.queryError = StateError('offline');
      anyCollectionWalls = <Map<String, dynamic>>[];

      await getCollectionWithName('space');

      expect(anyCollectionWalls.map((wall) => wall['id']), <String>['one']);
    });

    test('keeps a successful remote page when cache persistence fails', () async {
      await getIt.unregister<FeedCacheLocalDataSource>();
      getIt.registerSingleton<FeedCacheLocalDataSource>(_ThrowingFeedCache());
      firestore.onQuery = (_) => <FakeDocRow>[(id: 'd1', data: _wall('one'))];

      await getCollectionWithName('space');

      expect(anyCollectionWalls.map((wall) => wall['id']), <String>['one']);
      expect(collectionHasMore, isFalse);
    });

    test('returns saved walls when the remote query never completes', () async {
      final FakeFeedCacheLocalDataSource cache = FakeFeedCacheLocalDataSource();
      cache.snapshots['collections/walls.space'] = FeedSnapshot(
        payload: OfflineSnapshotCodec.encodeCollectionWalls(
          items: <Map<String, dynamic>>[_wall('saved')],
          lastDocId: 'saved-doc',
          hasMore: true,
          preserveLastItemsCount: 1,
        ),
        cachedAtUtc: DateTime.now().toUtc(),
        ttlHours: 24,
      );
      await getIt.unregister<FeedCacheLocalDataSource>();
      getIt.registerSingleton<FeedCacheLocalDataSource>(cache);
      await getIt.unregister<FirestoreClient>();
      getIt.registerSingleton<FirestoreClient>(_HangingFirestoreClient());

      await getCollectionWithName('space');

      expect(anyCollectionWalls.map((wall) => wall['id']), <String>['saved']);
      expect(collectionHasMore, isTrue);
    });

    test('filters saved walls after the current owner block snapshot is ready', () async {
      final FakeFeedCacheLocalDataSource cache = FakeFeedCacheLocalDataSource();
      cache.snapshots['collections/walls.space'] = FeedSnapshot(
        payload: OfflineSnapshotCodec.encodeCollectionWalls(
          items: <Map<String, dynamic>>[_wall('blocked')],
          lastDocId: 'blocked-doc',
          hasMore: false,
          preserveLastItemsCount: 1,
        ),
        cachedAtUtc: DateTime.now().toUtc(),
        ttlHours: 24,
      );
      final _PendingBlockRepository blocks = _PendingBlockRepository();
      await getIt.unregister<UserBlockRepository>();
      getIt.registerSingleton<UserBlockRepository>(blocks);
      await getIt.unregister<FeedCacheLocalDataSource>();
      getIt.registerSingleton<FeedCacheLocalDataSource>(cache);
      firestore.queryError = StateError('offline');

      final Future<void> opening = getCollectionWithName('space');
      await blocks.requested.future;
      blocks.completeInitial(<String>{'blocked'});
      try {
        await opening;
      } on Object {}

      expect(anyCollectionWalls, isEmpty);
    });
  });

  test('collection wall codec drops old items before the incoming page at the durable limit', () {
    final List<Map<String, dynamic>> oldPage = List<Map<String, dynamic>>.generate(
      50,
      (index) => <String, dynamic>{'id': 'old-$index', 'metadata': 'x' * 10000},
    );
    final Map<String, Object?> snapshot = OfflineSnapshotCodec.encodeCollectionWalls(
      items: <Map<String, dynamic>>[...oldPage, _wall('new')],
      lastDocId: 'new-doc',
      hasMore: false,
      preserveLastItemsCount: 1,
    );

    expect((snapshot['items']! as List).last['id'], 'new');
    expect(OfflineSnapshotCodec.maxSnapshotBytes, FeedCacheLocalDataSource.maxSnapshotBytes);
  });
}
