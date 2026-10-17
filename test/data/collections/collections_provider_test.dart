import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart';
import 'package:Prism/data/offline/offline_snapshot_codec.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';
import '../../support/fake_user_block_repository.dart';
import '../../support/fake_feed_cache_local_data_source.dart';

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
  Future<Set<String>> getBlockedCreatorEmails({bool waitForInitialLoad = false}) {
    if (waitForInitialLoad && !requested.isCompleted) requested.complete();
    return super.getBlockedCreatorEmails(waitForInitialLoad: waitForInitialLoad);
  }
}

Map<String, dynamic> _wall(String id) => <String, dynamic>{'id': id, 'email': '$id@example.com'};

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
      blocks.completeInitial(<String>{'blocked@example.com'});
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
