import 'dart:async';
import 'dart:math';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/trending/data/repositories/trending_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_feed_cache_local_data_source.dart';
import '../../../support/fake_firestore_client.dart';
import '../../../support/fake_user_block_repository.dart';
import '../../../support/in_memory_local_store.dart';

Map<String, dynamic> _wall(String id, {String creatorUid = 'creator-id', String? category}) => <String, dynamic>{
  'id': id,
  'wallpaper_url': 'https://example.com/$id.jpg',
  'wallpaper_thumb': 'https://example.com/$id-thumb.jpg',
  'wallpaper_provider': 'Prism',
  'by': 'Ana',
  'creatorUid': creatorUid,
  'review': true,
  'category': ?category,
};

List<String> _idsOf(FirestoreQuerySpec spec) =>
    (spec.filters.singleWhere((filter) => filter.op == FirestoreFilterOp.whereIn).value! as List).cast<String>();

class _DelayedFeedCache extends FakeFeedCacheLocalDataSource {
  final Completer<void> release = Completer<void>();

  @override
  Future<FeedSnapshot?> read({required String source, required String scope}) async {
    await release.future;
    return super.read(source: source, scope: scope);
  }
}

class _FailingPointerClient extends FakeFirestoreClient {
  _FailingPointerClient(this.error);

  final FirestoreError error;

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic>, String) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async => throw error;
}

class _DelayedNoAppClient extends FakeFirestoreClient {
  _DelayedNoAppClient(this.initialization);

  final Completer<bool> initialization;

  Future<T?> _forwardFailure<T>(Future<T?> inner) async => await inner;

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic>, String) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async {
    final inner = Completer<T?>();
    scheduleMicrotask(() {
      inner.completeError(FirestoreError(message: 'not ready', code: 'no-app'));
      initialization.complete(true);
    });
    return await _forwardFailure(inner.future);
  }
}

void main() {
  late FakeFirestoreClient client;
  late FakeFeedCacheLocalDataSource cache;
  late FakeUserBlockRepository blocks;
  late SettingsLocalDataSource settings;
  late TrendingRepositoryImpl repository;
  late Map<String, Map<String, dynamic>> walls;

  void setList(String collection, List<Object?> ids) {
    client.docs[collection] = <String, Map<String, dynamic>>{
      'current': <String, dynamic>{'wallIds': ids},
    };
  }

  setUp(() {
    walls = <String, Map<String, dynamic>>{};
    client = FakeFirestoreClient(
      onQuery: (spec) => <FakeDocRow>[
        for (final String id in _idsOf(spec).toList()..shuffle(Random(7)))
          if (walls.containsKey(id)) (id: 'doc-$id', data: walls[id]!),
      ],
    );
    cache = FakeFeedCacheLocalDataSource();
    blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    repository = TrendingRepositoryImpl(client, cache, blocks, settings);
  });

  test('keeps the order of the id list, not the order Firestore answers in', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A'), 'B': _wall('B'), 'C': _wall('C')};
    setList('trending', <Object?>['C', 'A', 'B']);

    final result = (await repository.fetch()).result;

    expect(result.data!.map((wall) => wall.id), <String>['C', 'A', 'B']);
  });

  test('protected thumbnail previews remain visible online and from cache without an original', () async {
    const thumb =
        'https://images.example.com/previews/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.img';
    walls = <String, Map<String, dynamic>>{
      'A': <String, dynamic>{..._wall('A'), 'wallpaper_url': '', 'wallpaper_thumb': thumb, 'originalProtected': true},
    };
    setList('trending', <Object?>['A']);
    final online = (await repository.fetch()).result.data!.single;
    expect(online.id, 'A');
    expect(online.firestoreDocumentId, 'doc-A');
    expect(online.fullUrl, isEmpty);
    expect(online.thumbnailUrl, thumb);
    client.queryError = StateError('offline');
    final offline = (await repository.fetch()).result.data!.single;
    expect(offline.fullUrl, isEmpty);
    expect(offline.thumbnailUrl, thumb);
  });

  test('loads the walls in batches of at most 30 ids and keeps the order across batches', () async {
    final List<String> ids = List<String>.generate(65, (i) => 'W${i.toString().padLeft(2, '0')}');
    walls = <String, Map<String, dynamic>>{for (final String id in ids) id: _wall(id)};
    setList('trending', ids);

    final result = (await repository.fetch()).result;

    final List<FirestoreQuerySpec> wallQueries = client.querySpecs;
    expect(wallQueries.map((spec) => _idsOf(spec).length), <int>[30, 30, 5]);
    expect(wallQueries.every((spec) => spec.collection == 'walls'), isTrue);
    expect(result.data!.map((wall) => wall.id), ids);
  });

  test('reads trending/current, not the all-time popular/current', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A'), 'B': _wall('B')};
    setList('trending', <Object?>['A']);
    setList('popular', <Object?>['B']);

    expect((await repository.fetch()).result.data!.map((wall) => wall.id), <String>['A']);
  });

  test('only asks for reviewed walls', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A')};
    setList('trending', <Object?>['A']);

    await repository.fetch();

    final FirestoreFilter review = client.querySpecs.single.filters.firstWhere((filter) => filter.field == 'review');
    expect(review.value, true);
  });

  test('drops walls that are missing, from blocked creators, or without an image', () async {
    walls = <String, Map<String, dynamic>>{
      'A': _wall('A'),
      'B': _wall('B', creatorUid: 'blocked-uid'),
      'D': <String, dynamic>{..._wall('D'), 'wallpaper_url': '', 'wallpaper_thumb': ''},
      'E': _wall('E'),
    };
    blocks.completeInitial(<String>{'blocked-uid'});
    setList('trending', <Object?>['A', 'B', 'MISSING', 'D', 'E']);

    final result = (await repository.fetch()).result;

    expect(result.data!.map((wall) => wall.id), <String>['A', 'E']);
  });

  test('with an unknown block list, drops walls that have a creator and keeps one without', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A'), 'N': _wall('N', creatorUid: '')};
    setList('trending', <Object?>['A', 'N']);
    final TrendingRepositoryImpl unloaded = TrendingRepositoryImpl(
      client,
      cache,
      FakeUserBlockRepository.pending()..timeOutInitialLoad(),
      settings,
    );

    final result = (await unloaded.fetch()).result;

    expect(result.data!.map((wall) => wall.id), <String>['N']);
  });

  test('upper-cases and de-duplicates the ids, and ignores blank ones', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A'), 'B': _wall('B')};
    setList('trending', <Object?>['a', 'A', ' ', null, 'b']);

    final result = (await repository.fetch()).result;

    expect(_idsOf(client.querySpecs.single), <String>['A', 'B']);
    expect(result.data!.map((wall) => wall.id), <String>['A', 'B']);
  });

  test('a missing or empty list gives an empty success without a wall query', () async {
    final missing = (await repository.fetch()).result;
    setList('trending', <Object?>[]);
    final empty = (await repository.fetch()).result;

    expect(missing.isSuccess, isTrue);
    expect(missing.data, isEmpty);
    expect(empty.data, isEmpty);
    expect(client.querySpecs, isEmpty);
  });

  test('a good empty list replaces the saved one, so a later failure does not bring old walls back', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A')};
    setList('trending', <Object?>['A']);
    expect((await repository.fetch()).result.data, hasLength(1));

    setList('trending', <Object?>[]);
    expect((await repository.fetch()).result.data, isEmpty);
    setList('trending', <Object?>['A']);
    client.queryError = Exception('offline');
    final offline = (await repository.fetch()).result;

    expect(offline.isSuccess, isTrue);
    expect(offline.data, isEmpty);
  });

  test('a saved empty list is a success when the network fails', () async {
    setList('trending', <Object?>[]);
    await repository.fetch();
    setList('trending', <Object?>['A']);
    client.queryError = Exception('offline');

    final offline = (await repository.fetch()).result;

    expect(offline.isSuccess, isTrue);
    expect(offline.data, isEmpty);
  });

  test('returns the saved list when the network fails, and hides creators blocked since', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A'), 'B': _wall('B', creatorUid: 'later-uid')};
    setList('trending', <Object?>['A', 'B']);
    expect((await repository.fetch()).result.data, hasLength(2));
    expect(cache.scopes, <String>['trending/week']);

    client.queryError = Exception('offline');
    blocks.completeInitial(<String>{'later-uid'});
    final offline = (await repository.fetch()).result;

    expect(offline.isSuccess, isTrue);
    expect(offline.data!.map((wall) => wall.id), <String>['A']);
  });

  test('readCached returns the saved walls without a network read and hides blocked creators', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A'), 'B': _wall('B', creatorUid: 'later-uid')};
    setList('trending', <Object?>['A', 'B']);
    await repository.fetch();
    client.queryError = Exception('offline');
    blocks.completeInitial(<String>{'later-uid'});

    final saved = await repository.readCached();

    expect(saved.map((wall) => wall.id), <String>['A']);
  });

  test('readCached is empty when nothing is saved', () async {
    expect(await repository.readCached(), isEmpty);
  });

  test('readCached excludes creators blocked while the disk read was pending', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A', creatorUid: 'later-uid')};
    setList('trending', <Object?>['A']);
    await repository.fetch();
    final delayed = _DelayedFeedCache()..snapshots.addAll(cache.snapshots);
    final pending = TrendingRepositoryImpl(client, delayed, blocks, settings).readCached();

    blocks.completeInitial(<String>{'later-uid'});
    delayed.release.complete();

    expect(await pending, isEmpty);
  });

  test('readCached waits for initial blocks before exposing cached creators', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A', creatorUid: 'later-uid')};
    setList('trending', <Object?>['A']);
    await repository.fetch();
    final pendingBlocks = FakeUserBlockRepository.pending();
    bool returned = false;
    final pending = TrendingRepositoryImpl(client, cache, pendingBlocks, settings).readCached().then((walls) {
      returned = true;
      return walls;
    });
    await Future<void>.delayed(Duration.zero);
    expect(returned, isFalse);
    pendingBlocks.completeInitial(<String>{'later-uid'});

    expect(await pending, isEmpty);
  });

  test('saves the walls unfiltered, so a creator unblocked since gets their walls back offline', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A'), 'B': _wall('B', creatorUid: 'later-uid')};
    setList('trending', <Object?>['A', 'B']);
    blocks.completeInitial(<String>{'later-uid'});
    expect((await repository.fetch()).result.data!.map((wall) => wall.id), <String>['A']);

    client.queryError = Exception('offline');
    blocks.completeInitial(<String>{});
    final offline = (await repository.fetch()).result;

    expect(offline.data!.map((wall) => wall.id), <String>['A', 'B']);
  });

  test('hides anime walls online and from cache while the anime setting is off', () async {
    walls = <String, Map<String, dynamic>>{'A': _wall('A', category: 'Anime'), 'B': _wall('B', category: 'Nature')};
    setList('trending', <Object?>['A', 'B']);

    expect((await repository.fetch()).result.data!.map((wall) => wall.id), <String>['B']);
    expect((await repository.readCached()).map((wall) => wall.id), <String>['B']);

    await settings.set('WHcategories', 110);
    expect((await repository.readCached()).map((wall) => wall.id), <String>['A', 'B']);
  });

  test('fails when the network fails and nothing is saved', () async {
    setList('trending', <Object?>['A']);
    client.queryError = Exception('offline');

    final result = (await repository.fetch()).result;

    expect(result.isFailure, isTrue);
    expect(result.failure, isA<ServerFailure>());
  });

  for (final bool hasCache in <bool>[false, true]) {
    test('pending initialization no-app carries recovery without waiting, cached=$hasCache', () async {
      if (hasCache) {
        walls = <String, Map<String, dynamic>>{'A': _wall('A')};
        setList('trending', <Object?>['A']);
        await repository.fetch();
      }
      final initialization = Completer<bool>();
      final startup = TrendingRepositoryImpl(
        _FailingPointerClient(FirestoreError(message: 'not ready', code: 'no-app')),
        cache,
        blocks,
        settings,
        initializationReady: () => initialization.future,
      );
      final outcome = await startup.fetch();
      expect(initialization.isCompleted, isFalse);
      expect(outcome.result.isSuccess, hasCache);
      expect(outcome.result.data?.map((wall) => wall.id), hasCache ? <String>['A'] : null);
      expect(outcome.retryAfterInitialization, isNotNull);
      initialization.complete(true);
      expect(await outcome.retryAfterInitialization, isTrue);
    });
  }

  test('initialization completing during cache read retains the pre-init failure provenance', () async {
    final initialization = Completer<bool>();
    final delayed = _DelayedFeedCache();
    final startup = TrendingRepositoryImpl(
      _FailingPointerClient(FirestoreError(message: 'not ready', code: 'no-app')),
      delayed,
      blocks,
      settings,
      initializationReady: () => initialization.future,
    );
    final pending = startup.fetch();
    await Future<void>.delayed(Duration.zero);
    initialization.complete(true);
    delayed.release.complete();
    final outcome = await pending;
    expect(outcome.retryAfterInitialization, isNotNull);
    expect(await outcome.retryAfterInitialization, isTrue);
  });

  for (final String code in <String>['permission-denied', 'unavailable']) {
    test('$code during pending initialization never carries a startup retry', () async {
      final initialization = Completer<bool>();
      final startup = TrendingRepositoryImpl(
        _FailingPointerClient(FirestoreError(message: code, code: code)),
        cache,
        blocks,
        settings,
        initializationReady: () => initialization.future,
      );
      final outcome = await startup.fetch();
      expect(outcome.result.isFailure, isTrue);
      expect(outcome.retryAfterInitialization, isNull);
      initialization.complete(true);
    });
  }

  test('a read that ran out of the bounded Firebase wait carries a startup retry', () async {
    final initialization = Completer<bool>();
    final startup = TrendingRepositoryImpl(
      _FailingPointerClient(FirestoreNotReadyError()),
      cache,
      blocks,
      settings,
      initializationReady: () => initialization.future,
    );
    final outcome = await startup.fetch();
    expect(outcome.result.isFailure, isTrue);
    expect(outcome.retryAfterInitialization, isNotNull);
    initialization.complete(true);
    expect(await outcome.retryAfterInitialization, isTrue);
  });

  test('no-app delivered after initialization settled still permits one startup retry', () async {
    final startup = TrendingRepositoryImpl(
      _FailingPointerClient(FirestoreError(message: 'no app', code: 'no-app')),
      cache,
      blocks,
      settings,
      initializationReady: () => Future<bool>.value(true),
    );
    final outcome = await startup.fetch();
    expect(outcome.result.isFailure, isTrue);
    expect(outcome.retryAfterInitialization, isNotNull);
    expect(await outcome.retryAfterInitialization, isTrue);
  });

  test('no-app thrown immediately before readiness retains its startup retry through async wrappers', () async {
    final initialization = Completer<bool>();
    final startup = TrendingRepositoryImpl(
      _DelayedNoAppClient(initialization),
      cache,
      blocks,
      settings,
      initializationReady: () => initialization.future,
    );
    final outcome = await startup.fetch();
    expect(outcome.result.isFailure, isTrue);
    expect(initialization.isCompleted, isTrue);
    expect(outcome.retryAfterInitialization, isNotNull);
    expect(await outcome.retryAfterInitialization, isTrue);
  });
}
