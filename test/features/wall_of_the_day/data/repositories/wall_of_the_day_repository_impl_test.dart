import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wall_of_the_day/data/repositories/wall_of_the_day_repository_impl.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wotd_past_pick.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_firestore_client.dart';
import '../../../../support/fake_feed_cache_local_data_source.dart';
import '../../../../support/fake_user_block_repository.dart';

class _MockPrismWallpaperRepository extends Mock implements PrismWallpaperRepository {}

class _DelayedFeedCache extends FakeFeedCacheLocalDataSource {
  final Completer<void> release = Completer<void>();

  @override
  Future<FeedSnapshot?> read({required String source, required String scope}) async {
    await release.future;
    return super.read(source: source, scope: scope);
  }
}

/// Serves a stale pointer from the "cache" when a caller asks for cache-first.
class _StaleCacheFirestoreClient extends FakeFirestoreClient {
  _StaleCacheFirestoreClient({super.docs});

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async {
    if (preferCacheFirst) {
      return map(<String, dynamic>{'wallId': 'wall-doc-1', 'date': DateTime.utc(2026)}, id);
    }
    return super.getById(collection, id, map, sourceTag: sourceTag);
  }
}

class _OfflinePointerFirestoreClient extends FakeFirestoreClient {
  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) => Future<T?>.error(FirestoreError(code: 'unavailable', message: 'offline'));
}

class _NoAppPointerFirestoreClient extends FakeFirestoreClient {
  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) => Future<T?>.error(FirestoreError(code: 'no-app', message: 'no app'));
}

class _DeniedPointerFirestoreClient extends FakeFirestoreClient {
  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) => Future<T?>.error(FirestoreError(code: 'permission-denied', message: 'denied'));
}

class _WotdMetadataFirestoreClient extends FakeFirestoreClient {
  _WotdMetadataFirestoreClient({super.onQuery, this.cacheOnly = false});

  final bool cacheOnly;

  @override
  Stream<({List<T> items, bool isFromCache})> watchQueryWithMetadata<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  ) {
    querySpecs.add(spec);
    final Object? error = queryError;
    if (error != null) return Stream<({List<T> items, bool isFromCache})>.error(error);
    final List<T> rows = (onQuery?.call(spec) ?? const <FakeDocRow>[])
        .map((row) => map(row.data, row.id))
        .toList(growable: false);
    return Stream<({List<T> items, bool isFromCache})>.value((items: rows, isFromCache: cacheOnly));
  }
}

class _ControlledWotdMetadataClient extends FakeFirestoreClient {
  void Function(List<FakeDocRow> rows)? emitCache;
  void Function(List<FakeDocRow> rows)? emitServer;
  void Function(Object error)? emitError;
  bool cancelled = false;
  Future<void> cancelFuture = Future<void>.value();

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
        return cancelFuture;
      },
    );
    List<T> convert(List<FakeDocRow> rows) => rows.map((row) => map(row.data, row.id)).toList(growable: false);
    emitCache = (rows) => controller.add((items: convert(rows), isFromCache: true));
    emitServer = (rows) => controller.add((items: convert(rows), isFromCache: false));
    emitError = controller.addError;
    return controller.stream;
  }
}

class _DelayedBlockRepository extends FakeUserBlockRepository {
  _DelayedBlockRepository() : super.pending();

  final Completer<Set<String>> snapshot = Completer<Set<String>>();

  @override
  Future<Set<String>> getBlockedCreatorEmails({bool waitForInitialLoad = false}) => waitForInitialLoad
      ? snapshot.future.then((blocked) {
          completeInitial(blocked);
          return blocked;
        })
      : super.getBlockedCreatorEmails();
}

PrismWallpaper _wall(String id, {String? url, String? thumbnailUrl, String? documentId, bool? review = true}) =>
    PrismWallpaper(
      core: WallpaperCore(
        id: id,
        source: WallpaperSource.prism,
        fullUrl: url ?? 'https://example.com/$id.jpg',
        thumbnailUrl: thumbnailUrl ?? 'https://example.com/$id-thumb.jpg',
      ),
      review: review,
      firestoreDocumentId: documentId,
    );

void main() {
  late FakeFirestoreClient firestoreClient;
  late _MockPrismWallpaperRepository prismRepository;

  setUp(() {
    firestoreClient = FakeFirestoreClient(
      docs: <String, Map<String, Map<String, dynamic>>>{
        FirebaseCollections.wallOfTheDay: <String, Map<String, dynamic>>{
          'current': <String, dynamic>{'wallId': 'wall-doc-1', 'date': DateTime.utc(2026)},
        },
      },
    );
    prismRepository = _MockPrismWallpaperRepository();
  });

  test('hides a cached pick once its creator becomes blocked, without a refetch', () async {
    when(() => prismRepository.fetchByDocumentId('wall-doc-1')).thenAnswer(
      (_) async => Result.success(
        const PrismWallpaper(
          core: WallpaperCore(
            id: 'wall-1',
            source: WallpaperSource.prism,
            fullUrl: 'https://example.com/wall-1.jpg',
            thumbnailUrl: 'https://example.com/wall-1-thumb.jpg',
            authorEmail: 'creator@example.com',
          ),
          review: true,
        ),
      ),
    );
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final repo = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blockRepo);

    final firstFetch = await repo.fetchToday();
    expect(firstFetch.data?.wallId, 'wall-1', reason: 'not blocked yet, so the pick shows');

    // The caller blocks the creator; a later screen visit re-fetches WOTD, hitting the
    // repo's own day-scoped cache (no further prismRepository.fetchByDocumentId call).
    blockRepo.completeInitial(<String>{'creator@example.com'});
    final secondFetch = await repo.fetchToday();

    expect(secondFetch.data, isNull, reason: 'the cached pick must disappear once its creator is blocked');
    verify(() => prismRepository.fetchByDocumentId('wall-doc-1')).called(1);
  });

  test('protected today and archive previews retain empty originals online and offline', () async {
    firestoreClient = _WotdMetadataFirestoreClient()..docs.addAll(firestoreClient.docs);
    final today = DateTime.now().toUtc();
    const thumb = 'https://staging.example.test/ownedThumbnail/wall-1';
    const protected = PrismWallpaper(
      core: WallpaperCore(id: 'wall-1', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: thumb),
      firestoreDocumentId: 'wall-doc-1',
      review: true,
    );
    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': 'wall-doc-1',
      'date': today.toIso8601String(),
    };
    firestoreClient.onQuery = (_) => <FakeDocRow>[
      (id: 'today', data: <String, dynamic>{'wallId': 'wall-doc-1', 'date': today.toIso8601String()}),
    ];
    when(() => prismRepository.fetchByDocumentId('wall-doc-1')).thenAnswer((_) async => Result.success(protected));
    final cache = FakeFeedCacheLocalDataSource();
    final blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final repo = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blocks, feedCacheLocal: cache);
    final pick = (await repo.fetchToday()).data!;
    expect(pick.wallId, 'wall-1');
    expect(pick.url, isEmpty);
    expect(pick.thumbnailUrl, thumb);
    final archive = (await repo.fetchRecent()).data!.single;
    expect(archive.wallpaper.fullUrl, isEmpty);
    expect(archive.wallpaper.thumbnailUrl, thumb);
    final offline = WallOfTheDayRepositoryImpl(
      _OfflinePointerFirestoreClient(),
      prismRepository,
      blocks,
      feedCacheLocal: cache,
    );
    final cached = (await offline.fetchToday()).data!;
    expect(cached.url, isEmpty);
    expect(cached.thumbnailUrl, thumb);
  });

  test('reads the pointer without cache-first so a new daily pick shows', () async {
    final client = _StaleCacheFirestoreClient(docs: firestoreClient.docs);
    when(
      () => prismRepository.fetchByDocumentId('wall-doc-1'),
    ).thenAnswer((_) async => Result.success(_wall('wall-1')));
    when(
      () => prismRepository.fetchByDocumentId('wall-doc-2'),
    ).thenAnswer((_) async => Result.success(_wall('wall-2')));
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final repo = WallOfTheDayRepositoryImpl(client, prismRepository, blockRepo);

    expect((await repo.fetchToday()).data?.wallId, 'wall-1');

    client.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': 'wall-doc-2',
      'date': DateTime.utc(2026),
    };
    expect((await repo.fetchToday()).data?.wallId, 'wall-2');
  });

  test('a current-day snapshot restores after a repository restart when the pointer is offline', () async {
    final DateTime today = DateTime.now().toUtc();
    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': 'wall-doc-1',
      'date': today.toIso8601String(),
    };
    when(
      () => prismRepository.fetchByDocumentId('wall-doc-1'),
    ).thenAnswer((_) async => Result.success(_wall('wall-1')));
    final FeedCacheLocalDataSource cache = FakeFeedCacheLocalDataSource();
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final first = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blockRepo, feedCacheLocal: cache);
    expect((await first.fetchToday()).data?.wallId, 'wall-1');

    final restarted = WallOfTheDayRepositoryImpl(
      _OfflinePointerFirestoreClient(),
      prismRepository,
      blockRepo,
      feedCacheLocal: cache,
    );

    expect((await restarted.fetchToday()).data?.wallId, 'wall-1');
  });

  test('an offline cached pick waits for the current owner block snapshot', () async {
    final DateTime today = DateTime.now().toUtc();
    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': 'wall-doc-1',
      'date': today.toIso8601String(),
    };
    when(() => prismRepository.fetchByDocumentId('wall-doc-1')).thenAnswer(
      (_) async => Result.success(
        const PrismWallpaper(
          core: WallpaperCore(
            id: 'wall-1',
            source: WallpaperSource.prism,
            fullUrl: 'https://example.com/wall-1.jpg',
            thumbnailUrl: 'https://example.com/wall-1-thumb.jpg',
            authorEmail: 'blocked@example.test',
          ),
          review: true,
        ),
      ),
    );
    final FeedCacheLocalDataSource cache = FakeFeedCacheLocalDataSource();
    final FakeUserBlockRepository unblocked = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final first = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, unblocked, feedCacheLocal: cache);
    expect((await first.fetchToday()).data?.wallId, 'wall-1');

    final _DelayedBlockRepository blocks = _DelayedBlockRepository();
    final restarted = WallOfTheDayRepositoryImpl(
      _OfflinePointerFirestoreClient(),
      prismRepository,
      blocks,
      feedCacheLocal: cache,
    );
    final Future<Result<WallOfTheDayEntity?>> pending = restarted.fetchToday();
    await Future<void>.delayed(Duration.zero);
    blocks.snapshot.complete(<String>{'blocked@example.test'});

    expect((await pending).data, isNull);
  });

  test('an older saved pick is never returned as today', () async {
    final DateTime yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': 'wall-doc-1',
      'date': yesterday.toIso8601String(),
    };
    when(
      () => prismRepository.fetchByDocumentId('wall-doc-1'),
    ).thenAnswer((_) async => Result.success(_wall('wall-1')));
    final FeedCacheLocalDataSource cache = FakeFeedCacheLocalDataSource();
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final previousDay = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blockRepo, feedCacheLocal: cache);
    expect((await previousDay.fetchToday()).data?.wallId, 'wall-1');
    final restarted = WallOfTheDayRepositoryImpl(
      _OfflinePointerFirestoreClient(),
      prismRepository,
      blockRepo,
      feedCacheLocal: cache,
    );

    expect((await restarted.fetchToday()).data, isNull);
  });

  test('same pointer reuses the day cache, then changed featured day refreshes the wall', () async {
    var fetchCount = 0;
    when(() => prismRepository.fetchByDocumentId('wall-doc-1')).thenAnswer((_) async {
      fetchCount++;
      return Result.success(_wall('wall-1', url: 'https://example.com/version-$fetchCount.jpg'));
    });
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final repo = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blockRepo);

    expect((await repo.fetchToday()).data?.url, 'https://example.com/version-1.jpg');
    expect((await repo.fetchToday()).data?.url, 'https://example.com/version-1.jpg');
    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': 'wall-doc-1',
      'date': DateTime.utc(2026, 1, 2),
    };
    expect((await repo.fetchToday()).data?.url, 'https://example.com/version-2.jpg');

    verify(() => prismRepository.fetchByDocumentId('wall-doc-1')).called(2);
  });

  test('missing and empty pointers return an empty result', () async {
    when(
      () => prismRepository.fetchByDocumentId('wall-doc-1'),
    ).thenAnswer((_) async => Result.success(_wall('wall-1')));
    when(
      () => prismRepository.fetchByDocumentId('wall-doc-2'),
    ).thenAnswer((_) async => Result.success(_wall('wall-2')));
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final repo = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blockRepo);

    expect((await repo.fetchToday()).data?.wallId, 'wall-1');
    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!.remove('current');
    expect((await repo.fetchToday()).data, isNull);

    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': '',
      'date': DateTime.utc(2026),
    };
    expect((await repo.fetchToday()).data, isNull);

    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': 'wall-doc-2',
      'date': DateTime.utc(2026),
    };
    expect((await repo.fetchToday()).data?.wallId, 'wall-2');
    verify(() => prismRepository.fetchByDocumentId('wall-doc-1')).called(1);
    verify(() => prismRepository.fetchByDocumentId('wall-doc-2')).called(1);
  });

  test('an authoritative missing pointer tombstones the durable today snapshot', () async {
    final Directory directory = Directory.systemTemp.createTempSync('wotd_missing_pointer_test');
    addTearDown(() => directory.deleteSync(recursive: true));
    final FeedCacheLocalDataSource cache = FeedCacheLocalDataSource(
      store: DurableJsonStore('wotd_missing_pointer_test', directory: directory),
    );
    final DateTime today = DateTime.now().toUtc();
    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': 'wall-doc-1',
      'date': today.toIso8601String(),
    };
    when(
      () => prismRepository.fetchByDocumentId('wall-doc-1'),
    ).thenAnswer((_) async => Result.success(_wall('wall-1')));
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final first = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blockRepo, feedCacheLocal: cache);
    expect((await first.fetchToday()).data?.wallId, 'wall-1');

    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!.remove('current');
    expect((await first.fetchToday()).data, isNull);

    final restarted = WallOfTheDayRepositoryImpl(
      _OfflinePointerFirestoreClient(),
      prismRepository,
      blockRepo,
      feedCacheLocal: cache,
    );
    expect((await restarted.fetchToday()).isFailure, isTrue);
  });

  test('a transient today lookup uses only a saved snapshot for the same pointer and day', () async {
    final Directory directory = Directory.systemTemp.createTempSync('wotd_transient_wall_test');
    addTearDown(() => directory.deleteSync(recursive: true));
    final FeedCacheLocalDataSource cache = FeedCacheLocalDataSource(
      store: DurableJsonStore('wotd_transient_wall_test', directory: directory),
    );
    final DateTime today = DateTime.now().toUtc();
    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': 'wall-doc-1',
      'date': today.toIso8601String(),
    };
    when(
      () => prismRepository.fetchByDocumentId('wall-doc-1'),
    ).thenAnswer((_) async => Result.success(_wall('wall-1')));
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final saved = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blockRepo, feedCacheLocal: cache);
    expect((await saved.fetchToday()).data?.wallId, 'wall-1');

    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': 'wall-doc-2',
      'date': today.toIso8601String(),
    };
    when(
      () => prismRepository.fetchByDocumentId('wall-doc-2'),
    ).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
    final changedPointer = await WallOfTheDayRepositoryImpl(
      firestoreClient,
      prismRepository,
      blockRepo,
      feedCacheLocal: cache,
    ).fetchToday();
    expect(changedPointer.isFailure, isTrue, reason: 'a different pointer must not reuse the prior pick');

    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': 'wall-doc-1',
      'date': today.toIso8601String(),
    };
    when(
      () => prismRepository.fetchByDocumentId('wall-doc-1'),
    ).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
    final matchingPointer = await WallOfTheDayRepositoryImpl(
      firestoreClient,
      prismRepository,
      blockRepo,
      feedCacheLocal: cache,
    ).fetchToday();
    expect(matchingPointer.data?.wallId, 'wall-1');
  });

  for (final ({String name, Result<PrismWallpaper?> invalidWall}) invalidCase
      in <({String name, Result<PrismWallpaper?> invalidWall})>[
        (name: 'missing wall', invalidWall: Result.success<PrismWallpaper?>(null)),
        (
          name: 'no image',
          invalidWall: Result.success<PrismWallpaper?>(_wall('wall-empty', url: '', thumbnailUrl: '')),
        ),
        (
          name: 'unreviewed wall',
          invalidWall: Result.success<PrismWallpaper?>(
            PrismWallpaper(
              core: WallpaperCore(
                id: 'wall-unreviewed',
                source: WallpaperSource.prism,
                fullUrl: 'https://example.com/wall-unreviewed.jpg',
                thumbnailUrl: 'https://example.com/wall-unreviewed-thumb.jpg',
              ),
              review: false,
            ),
          ),
        ),
      ]) {
    test('a successful ${invalidCase.name} lookup tombstones the durable today snapshot', () async {
      final Directory directory = Directory.systemTemp.createTempSync('wotd_invalid_wall_test');
      addTearDown(() => directory.deleteSync(recursive: true));
      final FeedCacheLocalDataSource cache = FeedCacheLocalDataSource(
        store: DurableJsonStore('wotd_invalid_wall_test', directory: directory),
      );
      final DateTime today = DateTime.now().toUtc();
      firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
        'wallId': 'wall-doc-1',
        'date': today.toIso8601String(),
      };
      when(
        () => prismRepository.fetchByDocumentId('wall-doc-1'),
      ).thenAnswer((_) async => Result.success(_wall('wall-old')));
      final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
      final saved = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blockRepo, feedCacheLocal: cache);
      expect((await saved.fetchToday()).data?.wallId, 'wall-old');

      firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
        'wallId': 'wall-doc-2',
        'date': today.toIso8601String(),
      };
      when(() => prismRepository.fetchByDocumentId('wall-doc-2')).thenAnswer((_) async => invalidCase.invalidWall);
      expect(
        (await WallOfTheDayRepositoryImpl(
          firestoreClient,
          prismRepository,
          blockRepo,
          feedCacheLocal: cache,
        ).fetchToday()).data,
        isNull,
      );

      when(
        () => prismRepository.fetchByDocumentId('wall-doc-2'),
      ).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
      final retry = await WallOfTheDayRepositoryImpl(
        firestoreClient,
        prismRepository,
        blockRepo,
        feedCacheLocal: cache,
      ).fetchToday();
      expect(retry.isFailure, isTrue, reason: 'the old pick must not be revived after restart');
    });
  }

  test('a pointer transport failure without a saved pick remains a failure', () async {
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final repo = WallOfTheDayRepositoryImpl(_OfflinePointerFirestoreClient(), prismRepository, blockRepo);

    final result = await repo.fetchToday();

    expect(result.isFailure, isTrue);
    expect(result.failure, isA<ServerFailure>());
  });

  test('a no-app startup error keeps the saved pick and readCachedToday still returns it', () async {
    final DateTime today = DateTime.now().toUtc();
    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': 'wall-doc-1',
      'date': today.toIso8601String(),
    };
    when(
      () => prismRepository.fetchByDocumentId('wall-doc-1'),
    ).thenAnswer((_) async => Result.success(_wall('wall-1')));
    final FeedCacheLocalDataSource cache = FakeFeedCacheLocalDataSource();
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    await WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blockRepo, feedCacheLocal: cache).fetchToday();

    final early = WallOfTheDayRepositoryImpl(
      _NoAppPointerFirestoreClient(),
      prismRepository,
      blockRepo,
      feedCacheLocal: cache,
    );
    expect((await early.fetchToday()).data?.wallId, 'wall-1');

    final restarted = WallOfTheDayRepositoryImpl(
      _OfflinePointerFirestoreClient(),
      prismRepository,
      blockRepo,
      feedCacheLocal: cache,
    );
    expect((await restarted.readCachedToday())?.wallId, 'wall-1');
  });

  test('readCachedToday is null when nothing is saved, without waiting for the block load', () async {
    final blockRepo = FakeUserBlockRepository.pending();
    final repo = WallOfTheDayRepositoryImpl(
      firestoreClient,
      prismRepository,
      blockRepo,
      feedCacheLocal: FakeFeedCacheLocalDataSource(),
    );

    expect(await repo.readCachedToday(), isNull);
  });

  test('readCachedToday excludes a creator blocked while the disk read was pending', () async {
    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current']!['date'] = DateTime.now()
        .toUtc()
        .toIso8601String();
    when(() => prismRepository.fetchByDocumentId('wall-doc-1')).thenAnswer(
      (_) async => Result.success(
        const PrismWallpaper(
          core: WallpaperCore(
            id: 'wall-1',
            source: WallpaperSource.prism,
            fullUrl: 'https://example.com/wall-1.jpg',
            thumbnailUrl: 'https://example.com/wall-1-thumb.jpg',
            authorEmail: 'creator@example.com',
          ),
          review: true,
        ),
      ),
    );
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final cache = _DelayedFeedCache();
    final repo = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blockRepo, feedCacheLocal: cache);
    expect((await repo.fetchToday()).data, isNotNull);

    final pending = repo.readCachedToday();
    blockRepo.completeInitial(<String>{'creator@example.com'});
    cache.release.complete();

    expect(await pending, isNull);
  });

  test('readCachedToday waits for initial blocks before exposing a cached creator', () async {
    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current']!['date'] = DateTime.now()
        .toUtc()
        .toIso8601String();
    when(() => prismRepository.fetchByDocumentId('wall-doc-1')).thenAnswer(
      (_) async => Result.success(
        const PrismWallpaper(
          core: WallpaperCore(
            id: 'wall-1',
            source: WallpaperSource.prism,
            fullUrl: 'https://example.com/wall-1.jpg',
            thumbnailUrl: '',
            authorEmail: 'creator@example.com',
          ),
          review: true,
        ),
      ),
    );
    final cache = FakeFeedCacheLocalDataSource();
    await WallOfTheDayRepositoryImpl(
      firestoreClient,
      prismRepository,
      FakeUserBlockRepository.pending()..completeInitial(<String>{}),
      feedCacheLocal: cache,
    ).fetchToday();
    final blocks = FakeUserBlockRepository.pending();
    bool returned = false;
    final pending = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blocks, feedCacheLocal: cache)
        .readCachedToday()
        .then((wall) {
          returned = true;
          return wall;
        });
    await Future<void>.delayed(Duration.zero);
    expect(returned, isFalse);
    blocks.completeInitial(<String>{'creator@example.com'});

    expect(await pending, isNull);
  });

  test('a permission-denied pointer tombstones the saved today snapshot across restart', () async {
    final Directory directory = Directory.systemTemp.createTempSync('wotd_denied_pointer_test');
    addTearDown(() => directory.deleteSync(recursive: true));
    final FeedCacheLocalDataSource cache = FeedCacheLocalDataSource(
      store: DurableJsonStore('wotd_denied_pointer_test', directory: directory),
    );
    final DateTime today = DateTime.now().toUtc();
    firestoreClient.docs[FirebaseCollections.wallOfTheDay]!['current'] = <String, dynamic>{
      'wallId': 'wall-doc-1',
      'date': today.toIso8601String(),
    };
    when(
      () => prismRepository.fetchByDocumentId('wall-doc-1'),
    ).thenAnswer((_) async => Result.success(_wall('wall-1')));
    final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final saved = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blockRepo, feedCacheLocal: cache);
    expect((await saved.fetchToday()).data?.wallId, 'wall-1');

    final denied = await WallOfTheDayRepositoryImpl(
      _DeniedPointerFirestoreClient(),
      prismRepository,
      blockRepo,
      feedCacheLocal: cache,
    ).fetchToday();
    expect(denied.isFailure, isTrue);
    expect(denied.failure?.code, 'permission-denied');

    final restarted = await WallOfTheDayRepositoryImpl(
      _OfflinePointerFirestoreClient(),
      prismRepository,
      blockRepo,
      feedCacheLocal: cache,
    ).fetchToday();
    expect(restarted.isFailure, isTrue, reason: 'permission denial must not let a restart resurrect the pick');
  });

  for (final ({String name, Result<PrismWallpaper?> firstAttempt}) retryCase
      in <({String name, Result<PrismWallpaper?> firstAttempt})>[
        (name: 'missing wall', firstAttempt: Result.success<PrismWallpaper?>(null)),
        (name: 'wall fetch failure', firstAttempt: Result.error<PrismWallpaper?>(const NetworkFailure('offline'))),
      ]) {
    test('${retryCase.name} can be retried and return the new wall', () async {
      var fetchCount = 0;
      when(() => prismRepository.fetchByDocumentId('wall-doc-1')).thenAnswer((_) async {
        fetchCount++;
        return fetchCount == 1 ? retryCase.firstAttempt : Result.success(_wall('wall-new'));
      });
      final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
      final repo = WallOfTheDayRepositoryImpl(firestoreClient, prismRepository, blockRepo);

      final firstAttempt = await repo.fetchToday();
      final retry = await repo.fetchToday();

      if (retryCase.name == 'wall fetch failure') {
        expect(firstAttempt.isFailure, isTrue);
      } else {
        expect(firstAttempt.data, isNull);
      }
      expect(retry.data?.wallId, 'wall-new');
      verify(() => prismRepository.fetchByDocumentId('wall-doc-1')).called(2);
    });
  }

  group('fetchRecent', () {
    PrismWallpaper reviewed(String id, {bool review = true, String url = '', String title = ''}) => PrismWallpaper(
      core: WallpaperCore(
        id: id,
        source: WallpaperSource.prism,
        fullUrl: url.isEmpty ? 'https://example.com/$id.jpg' : url,
        thumbnailUrl: 'https://example.com/$id-thumb.jpg',
      ),
      title: title,
      review: review,
    );

    WallOfTheDayRepositoryImpl repoWith(List<FakeDocRow> rows) {
      final _WotdMetadataFirestoreClient client = _WotdMetadataFirestoreClient(onQuery: (_) => rows);
      return WallOfTheDayRepositoryImpl(
        client,
        prismRepository,
        FakeUserBlockRepository.pending()..completeInitial(<String>{}),
      );
    }

    test('finishes after the 500ms grace when cache metadata is empty and server metadata never arrives', () {
      fakeAsync((async) {
        final _ControlledWotdMetadataClient client = _ControlledWotdMetadataClient();
        final FakeFeedCacheLocalDataSource cache = FakeFeedCacheLocalDataSource();
        final WallOfTheDayRepositoryImpl repo = WallOfTheDayRepositoryImpl(
          client,
          prismRepository,
          FakeUserBlockRepository.pending()..completeInitial(<String>{}),
          feedCacheLocal: cache,
        );
        Result<List<WotdPastPick>>? result;

        unawaited(repo.fetchRecent().then((value) => result = value));
        async.flushMicrotasks();
        client.emitCache!(<FakeDocRow>[]);
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 499));
        async.flushMicrotasks();
        expect(result, isNull);
        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();

        expect(result?.isFailure, isTrue);
        expect(client.cancelled, isTrue);
      });
    });

    test('bounds a metadata read with no events at eight seconds', () {
      fakeAsync((async) {
        final _ControlledWotdMetadataClient client = _ControlledWotdMetadataClient();
        final WallOfTheDayRepositoryImpl repo = WallOfTheDayRepositoryImpl(
          client,
          prismRepository,
          FakeUserBlockRepository.pending()..completeInitial(<String>{}),
          feedCacheLocal: FakeFeedCacheLocalDataSource(),
        );
        Result<List<WotdPastPick>>? result;

        unawaited(repo.fetchRecent().then((value) => result = value));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 7999));
        async.flushMicrotasks();
        expect(result, isNull);
        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();

        expect(result?.isFailure, isTrue);
        expect(client.cancelled, isTrue);
      });
    });

    test('a cached result completes even when subscription cancellation never resolves', () {
      fakeAsync((async) {
        final _ControlledWotdMetadataClient client = _ControlledWotdMetadataClient()
          ..cancelFuture = Completer<void>().future;
        final WallOfTheDayRepositoryImpl repo = WallOfTheDayRepositoryImpl(
          client,
          prismRepository,
          FakeUserBlockRepository.pending()..completeInitial(<String>{}),
          feedCacheLocal: FakeFeedCacheLocalDataSource(),
        );
        Result<List<WotdPastPick>>? result;

        unawaited(repo.fetchRecent().then((value) => result = value));
        async.flushMicrotasks();
        client.emitCache!(<FakeDocRow>[]);
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(result?.isFailure, isTrue);
        expect(client.cancelled, isTrue);
      });
    });

    test('an error still returns promptly when subscription cancellation never resolves', () {
      fakeAsync((async) {
        final _ControlledWotdMetadataClient client = _ControlledWotdMetadataClient()
          ..cancelFuture = Completer<void>().future;
        final WallOfTheDayRepositoryImpl repo = WallOfTheDayRepositoryImpl(
          client,
          prismRepository,
          FakeUserBlockRepository.pending()..completeInitial(<String>{}),
          feedCacheLocal: FakeFeedCacheLocalDataSource(),
        );
        Result<List<WotdPastPick>>? result;

        unawaited(repo.fetchRecent().then((value) => result = value));
        async.flushMicrotasks();
        client.emitError!(StateError('stream failed'));
        async.flushMicrotasks();

        expect(result?.isFailure, isTrue);
        expect(client.cancelled, isTrue);
      });
    });

    test('identical cache and server rows before grace still resolve and rewrite the archive', () async {
      final _ControlledWotdMetadataClient client = _ControlledWotdMetadataClient();
      final FakeFeedCacheLocalDataSource cache = FakeFeedCacheLocalDataSource();
      final FakeDocRow row = (
        id: '2026-01-04',
        data: <String, dynamic>{'wallId': 'doc-a', 'date': DateTime.utc(2026, 1, 4)},
      );
      when(
        () => prismRepository.fetchByDocumentId('doc-a'),
      ).thenAnswer((_) async => Result.success(_wall('wall-a', documentId: 'doc-a')));
      final WallOfTheDayRepositoryImpl repo = WallOfTheDayRepositoryImpl(
        client,
        prismRepository,
        FakeUserBlockRepository.pending()..completeInitial(<String>{}),
        feedCacheLocal: cache,
      );

      final Future<Result<List<WotdPastPick>>> pending = repo.fetchRecent();
      await Future<void>.delayed(Duration.zero);
      client.emitCache!(<FakeDocRow>[row]);
      client.emitServer!(<FakeDocRow>[row]);
      final Result<List<WotdPastPick>> result = await pending;

      expect(result.data?.map((pick) => pick.wallpaper.id), <String>['wall-a']);
      verify(() => prismRepository.fetchByDocumentId('doc-a')).called(1);
      expect(cache.scopes, contains('wotd/archive'));
      expect(client.cancelled, isTrue);
    });

    test('reads past_picks newest first, 30 at a time, with the wotd source tag', () async {
      final client = _WotdMetadataFirestoreClient();
      final repo = WallOfTheDayRepositoryImpl(
        client,
        prismRepository,
        FakeUserBlockRepository.pending()..completeInitial(<String>{}),
      );

      final result = await repo.fetchRecent();

      expect(result.data, isEmpty);
      final spec = client.querySpecs.single;
      expect(spec.collection, 'past_picks');
      expect(spec.sourceTag, 'wotd.past_picks');
      expect(spec.limit, 30);
      expect(spec.orderBy.single.field, 'date');
      expect(spec.orderBy.single.descending, isTrue);
    });

    test('archive stays within the encoded feed snapshot limit and keeps newest picks', () async {
      final List<FakeDocRow> rows = List<FakeDocRow>.generate(
        10,
        (index) => (
          id: '2026-01-${(10 - index).toString().padLeft(2, '0')}',
          data: <String, dynamic>{'wallId': 'doc-$index', 'date': DateTime.utc(2026, 1, 10 - index)},
        ),
      );
      for (var index = 0; index < 10; index++) {
        when(
          () => prismRepository.fetchByDocumentId('doc-$index'),
        ).thenAnswer((_) async => Result.success(reviewed('wall-$index', title: 'x' * (index == 0 ? 600000 : 70000))));
      }
      final FakeFeedCacheLocalDataSource cache = FakeFeedCacheLocalDataSource();
      final WallOfTheDayRepositoryImpl repo = WallOfTheDayRepositoryImpl(
        _WotdMetadataFirestoreClient(onQuery: (_) => rows),
        prismRepository,
        FakeUserBlockRepository.pending()..completeInitial(<String>{}),
        feedCacheLocal: cache,
      );

      expect((await repo.fetchRecent()).data, hasLength(10));
      final Object? payload = cache.snapshots['wotd/archive']!.payload;
      final List<Object?> saved = (payload as Map<String, Object?>)['picks']! as List<Object?>;
      final int encodedSnapshotBytes = utf8
          .encode(
            jsonEncode(<String, Object?>{
              'cachedAtUtc': cache.snapshots['wotd/archive']!.cachedAtUtc.toIso8601String(),
              'ttlHours': cache.snapshots['wotd/archive']!.ttlHours,
              'payload': payload,
            }),
          )
          .length;

      expect(saved.length, lessThan(10));
      expect(encodedSnapshotBytes, lessThanOrEqualTo(FeedCacheLocalDataSource.maxSnapshotBytes));
      expect((saved.first as Map<String, dynamic>)['item']['id'], 'wall-1');
    });

    for (final ({String name, List<FakeDocRow> rows}) cacheCase in <({String name, List<FakeDocRow> rows})>[
      (name: 'empty', rows: const <FakeDocRow>[]),
      (
        name: 'partial',
        rows: <FakeDocRow>[
          (id: '2026-01-04', data: <String, dynamic>{'wallId': 'doc-a', 'date': DateTime.utc(2026, 1, 4)}),
        ],
      ),
    ]) {
      test('a cache-only ${cacheCase.name} query preserves the saved archive across restart', () async {
        final FakeFeedCacheLocalDataSource cache = FakeFeedCacheLocalDataSource();
        final List<FakeDocRow> serverRows = <FakeDocRow>[
          for (final String id in <String>['doc-a', 'doc-b'])
            (id: id, data: <String, dynamic>{'wallId': id, 'date': DateTime.utc(2026, 1, 4)}),
        ];
        for (final String id in <String>['doc-a', 'doc-b']) {
          when(
            () => prismRepository.fetchByDocumentId(id),
          ).thenAnswer((_) async => Result.success(_wall('wall-$id', documentId: id)));
        }
        final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
        final _WotdMetadataFirestoreClient authoritative = _WotdMetadataFirestoreClient()..onQuery = (_) => serverRows;
        final WallOfTheDayRepositoryImpl writer = WallOfTheDayRepositoryImpl(
          authoritative,
          prismRepository,
          blockRepo,
          feedCacheLocal: cache,
        );
        expect((await writer.fetchRecent()).data, hasLength(2));
        final Object? savedPayload = cache.snapshots['wotd/archive']!.payload;

        final _WotdMetadataFirestoreClient cacheOnly = _WotdMetadataFirestoreClient(cacheOnly: true)
          ..onQuery = (_) => cacheCase.rows;
        final Result<List<WotdPastPick>> stale = await WallOfTheDayRepositoryImpl(
          cacheOnly,
          prismRepository,
          blockRepo,
          feedCacheLocal: cache,
        ).fetchRecent();
        expect(stale.data?.map((pick) => pick.wallpaper.id), <String>['wall-doc-a', 'wall-doc-b']);
        expect(cache.snapshots['wotd/archive']!.payload, savedPayload);

        final Result<List<WotdPastPick>> restarted = await WallOfTheDayRepositoryImpl(
          _WotdMetadataFirestoreClient(cacheOnly: true),
          prismRepository,
          blockRepo,
          feedCacheLocal: cache,
        ).fetchRecent();
        expect(restarted.data?.map((pick) => pick.wallpaper.id), <String>['wall-doc-a', 'wall-doc-b']);
        expect(cache.snapshots['wotd/archive']!.payload, savedPayload);
      });
    }

    test('an authoritative empty query clears the archive and stays empty offline', () async {
      final FakeFeedCacheLocalDataSource cache = FakeFeedCacheLocalDataSource();
      final FakeDocRow row = (
        id: '2026-01-04',
        data: <String, dynamic>{'wallId': 'doc-a', 'date': DateTime.utc(2026, 1, 4)},
      );
      when(
        () => prismRepository.fetchByDocumentId('doc-a'),
      ).thenAnswer((_) async => Result.success(_wall('wall-a', documentId: 'doc-a')));
      final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
      await WallOfTheDayRepositoryImpl(
        _WotdMetadataFirestoreClient(onQuery: (_) => <FakeDocRow>[row]),
        prismRepository,
        blockRepo,
        feedCacheLocal: cache,
      ).fetchRecent();

      final Result<List<WotdPastPick>> empty = await WallOfTheDayRepositoryImpl(
        _WotdMetadataFirestoreClient(),
        prismRepository,
        blockRepo,
        feedCacheLocal: cache,
      ).fetchRecent();
      expect(empty.data, isEmpty);
      final Result<List<WotdPastPick>> restarted = await WallOfTheDayRepositoryImpl(
        _WotdMetadataFirestoreClient(cacheOnly: true),
        prismRepository,
        blockRepo,
        feedCacheLocal: cache,
      ).fetchRecent();
      expect(restarted.data, isEmpty);
    });

    test('cache-only rows can serve a nonempty result but cannot create an archive or claim empty', () async {
      final FakeFeedCacheLocalDataSource cache = FakeFeedCacheLocalDataSource();
      final FakeDocRow row = (
        id: '2026-01-04',
        data: <String, dynamic>{'wallId': 'doc-a', 'date': DateTime.utc(2026, 1, 4)},
      );
      when(
        () => prismRepository.fetchByDocumentId('doc-a'),
      ).thenAnswer((_) async => Result.success(_wall('wall-a', documentId: 'doc-a')));
      final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});

      final Result<List<WotdPastPick>> cachedRows = await WallOfTheDayRepositoryImpl(
        _WotdMetadataFirestoreClient(cacheOnly: true, onQuery: (_) => <FakeDocRow>[row]),
        prismRepository,
        blockRepo,
        feedCacheLocal: cache,
      ).fetchRecent();
      expect(cachedRows.data?.single.wallpaper.id, 'wall-a');
      expect(cache.snapshots, isEmpty, reason: 'SDK-cache rows must not become the durable archive');

      final Result<List<WotdPastPick>> cachedEmpty = await WallOfTheDayRepositoryImpl(
        _WotdMetadataFirestoreClient(cacheOnly: true),
        prismRepository,
        blockRepo,
        feedCacheLocal: cache,
      ).fetchRecent();
      expect(cachedEmpty.isFailure, isTrue, reason: 'cache-only empty is not an authoritative empty archive');
      expect(cache.snapshots, isEmpty);
    });

    test('resolves each pick to its wall, keeps the order, and skips walls that are gone or not reviewed', () async {
      when(() => prismRepository.fetchByDocumentId('doc-a')).thenAnswer((_) async => Result.success(reviewed('a')));
      when(() => prismRepository.fetchByDocumentId('doc-gone')).thenAnswer((_) async => Result.success(null));
      when(
        () => prismRepository.fetchByDocumentId('doc-hidden'),
      ).thenAnswer((_) async => Result.success(reviewed('hidden', review: false)));
      when(() => prismRepository.fetchByDocumentId('doc-b')).thenAnswer((_) async => Result.success(reviewed('b')));
      final repo = repoWith(<FakeDocRow>[
        (id: '2026-01-04', data: <String, dynamic>{'wallId': 'doc-a', 'date': DateTime.utc(2026, 1, 4)}),
        (id: '2026-01-03', data: <String, dynamic>{'wallId': 'doc-gone', 'date': DateTime.utc(2026, 1, 3)}),
        (id: '2026-01-02', data: <String, dynamic>{'wallId': 'doc-hidden', 'date': DateTime.utc(2026, 1, 2)}),
        (id: '2026-01-01', data: <String, dynamic>{'wallId': 'doc-b'}),
      ]);

      final picks = (await repo.fetchRecent()).data!;

      expect(picks.map((pick) => pick.wallpaper.id), <String>['a', 'b']);
      expect(picks.first.date, DateTime.utc(2026, 1, 4));
      expect(picks.last.date, DateTime.parse('2026-01-01'), reason: 'a pick with no date field uses its doc id');
    });

    test('a pointer with no wall id or no usable date is skipped without a lookup', () async {
      final repo = repoWith(<FakeDocRow>[
        (id: '2026-01-04', data: <String, dynamic>{'wallId': '', 'date': DateTime.utc(2026, 1, 4)}),
        (id: 'not-a-date', data: <String, dynamic>{'wallId': 'doc-a'}),
      ]);

      expect((await repo.fetchRecent()).data, isEmpty);
      verifyNever(() => prismRepository.fetchByDocumentId(any()));
    });

    test('a failed query is an error with a message the user can read', () async {
      final _WotdMetadataFirestoreClient client = _WotdMetadataFirestoreClient()
        ..queryError = StateError('[cloud_firestore/unavailable] offline');
      final repo = WallOfTheDayRepositoryImpl(
        client,
        prismRepository,
        FakeUserBlockRepository.pending()..completeInitial(<String>{}),
      );

      final result = await repo.fetchRecent();

      expect(result.failure!.message, "Couldn't load past picks. Check your connection and try again.");
    });

    test('when every wall lookup fails the archive reports the failure instead of an empty list', () async {
      when(
        () => prismRepository.fetchByDocumentId(any()),
      ).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
      final repo = repoWith(<FakeDocRow>[
        (id: '2026-01-04', data: <String, dynamic>{'wallId': 'doc-a', 'date': DateTime.utc(2026, 1, 4)}),
      ]);

      expect((await repo.fetchRecent()).isFailure, isTrue);
    });

    test('one failed lookup among good ones only drops that pick', () async {
      when(() => prismRepository.fetchByDocumentId('doc-a')).thenAnswer((_) async => Result.success(reviewed('a')));
      when(
        () => prismRepository.fetchByDocumentId('doc-b'),
      ).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
      final repo = repoWith(<FakeDocRow>[
        (id: '2026-01-04', data: <String, dynamic>{'wallId': 'doc-a', 'date': DateTime.utc(2026, 1, 4)}),
        (id: '2026-01-03', data: <String, dynamic>{'wallId': 'doc-b', 'date': DateTime.utc(2026, 1, 3)}),
      ]);

      expect((await repo.fetchRecent()).data!.map((pick) => pick.wallpaper.id), <String>['a']);
    });

    test('transient lookup failures retain matching archive rows and remove confirmed missing rows', () async {
      final Directory directory = Directory.systemTemp.createTempSync('wotd_archive_test');
      addTearDown(() => directory.deleteSync(recursive: true));
      final FeedCacheLocalDataSource cache = FeedCacheLocalDataSource(
        store: DurableJsonStore('wotd_archive_test', directory: directory),
      );
      final List<FakeDocRow> initialRows = <FakeDocRow>[
        for (final String id in <String>['doc-good', 'doc-retry', 'doc-deleted'])
          (id: id, data: <String, dynamic>{'wallId': id, 'date': DateTime.utc(2026, 1, 4)}),
      ];
      final _WotdMetadataFirestoreClient client = _WotdMetadataFirestoreClient()..onQuery = (_) => initialRows;
      for (final String id in <String>['doc-good', 'doc-retry', 'doc-deleted']) {
        when(
          () => prismRepository.fetchByDocumentId(id),
        ).thenAnswer((_) async => Result.success(_wall('wall-$id', documentId: id, review: true)));
      }
      WallOfTheDayRepositoryImpl createRepository() => WallOfTheDayRepositoryImpl(
        client,
        prismRepository,
        FakeUserBlockRepository.pending()..completeInitial(<String>{}),
        feedCacheLocal: cache,
      );
      final WallOfTheDayRepositoryImpl repo = createRepository();
      expect((await repo.fetchRecent()).data, hasLength(3));
      final FeedSnapshot archivedBefore = (await cache.read(source: 'wotd', scope: 'archive'))!;

      client.onQuery = (_) => <FakeDocRow>[initialRows[0], initialRows[1], initialRows[2]];
      when(
        () => prismRepository.fetchByDocumentId('doc-good'),
      ).thenAnswer((_) async => Result.success(_wall('wall-doc-good', documentId: 'doc-good')));
      when(
        () => prismRepository.fetchByDocumentId('doc-retry'),
      ).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
      when(() => prismRepository.fetchByDocumentId('doc-deleted')).thenAnswer((_) async => Result.success(null));

      final List<WotdPastPick> picks = (await createRepository().fetchRecent()).data!;
      final FeedSnapshot archivedAfter = (await cache.read(source: 'wotd', scope: 'archive'))!;

      expect(picks.map((pick) => pick.wallpaper.id), <String>['wall-doc-good', 'wall-doc-retry']);
      expect(archivedAfter.payload, isNot(archivedBefore.payload));
      expect(
        (archivedAfter.payload! as Map<String, dynamic>)['picks'],
        hasLength(2),
        reason: 'the confirmed missing row is removed while the transient row is retained',
      );

      when(
        () => prismRepository.fetchByDocumentId(any()),
      ).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
      final List<WotdPastPick> afterRestart = (await createRepository().fetchRecent()).data!;
      expect(afterRestart.map((pick) => pick.wallpaper.id), <String>['wall-doc-good', 'wall-doc-retry']);
    });

    test('mixed failures prune confirmed missing rows and retain only transient archive fallbacks', () async {
      final Directory directory = Directory.systemTemp.createTempSync('wotd_mixed_errors_test');
      addTearDown(() => directory.deleteSync(recursive: true));
      final FeedCacheLocalDataSource cache = FeedCacheLocalDataSource(
        store: DurableJsonStore('wotd_mixed_errors_test', directory: directory),
      );
      final List<FakeDocRow> rows = <FakeDocRow>[
        for (final String id in <String>['doc-good', 'doc-retry', 'doc-deleted', 'doc-denied'])
          (id: id, data: <String, dynamic>{'wallId': id, 'date': DateTime.utc(2026, 1, 4)}),
      ];
      final _WotdMetadataFirestoreClient client = _WotdMetadataFirestoreClient()..onQuery = (_) => rows;
      final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
      for (final String id in <String>['doc-good', 'doc-retry', 'doc-deleted', 'doc-denied']) {
        when(
          () => prismRepository.fetchByDocumentId(id),
        ).thenAnswer((_) async => Result.success(_wall('wall-$id', documentId: id)));
      }
      WallOfTheDayRepositoryImpl createRepository() =>
          WallOfTheDayRepositoryImpl(client, prismRepository, blockRepo, feedCacheLocal: cache);
      await createRepository().fetchRecent();

      when(
        () => prismRepository.fetchByDocumentId('doc-good'),
      ).thenAnswer((_) async => Result.success(_wall('wall-good-new', documentId: 'doc-good', review: true)));
      when(
        () => prismRepository.fetchByDocumentId('doc-retry'),
      ).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
      when(() => prismRepository.fetchByDocumentId('doc-deleted')).thenAnswer((_) async => Result.success(null));
      when(
        () => prismRepository.fetchByDocumentId('doc-denied'),
      ).thenAnswer((_) async => Result.error(const ServerFailure('permission denied')));

      final Result<List<WotdPastPick>> mixed = await createRepository().fetchRecent();
      expect(mixed.data?.map((pick) => pick.wallpaper.id), <String>['wall-good-new']);

      when(
        () => prismRepository.fetchByDocumentId(any()),
      ).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
      final Result<List<WotdPastPick>> offline = await createRepository().fetchRecent();
      expect(offline.data?.map((pick) => pick.wallpaper.id), <String>['wall-good-new', 'wall-doc-retry']);
    });

    test('a denied row is pruned and stays pruned across restart without a successful null row', () async {
      final Directory directory = Directory.systemTemp.createTempSync('wotd_denied_archive_test');
      addTearDown(() => directory.deleteSync(recursive: true));
      final FeedCacheLocalDataSource cache = FeedCacheLocalDataSource(
        store: DurableJsonStore('wotd_denied_archive_test', directory: directory),
      );
      final List<FakeDocRow> rows = <FakeDocRow>[
        for (final String id in <String>['doc-good', 'doc-denied'])
          (id: id, data: <String, dynamic>{'wallId': id, 'date': DateTime.utc(2026, 1, 4)}),
      ];
      final _WotdMetadataFirestoreClient client = _WotdMetadataFirestoreClient()..onQuery = (_) => rows;
      final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
      for (final String id in <String>['doc-good', 'doc-denied']) {
        when(
          () => prismRepository.fetchByDocumentId(id),
        ).thenAnswer((_) async => Result.success(_wall('wall-$id', documentId: id)));
      }
      WallOfTheDayRepositoryImpl repository() =>
          WallOfTheDayRepositoryImpl(client, prismRepository, blockRepo, feedCacheLocal: cache);
      await repository().fetchRecent();

      when(
        () => prismRepository.fetchByDocumentId('doc-good'),
      ).thenAnswer((_) async => Result.success(_wall('wall-good-new', documentId: 'doc-good')));
      when(
        () => prismRepository.fetchByDocumentId('doc-denied'),
      ).thenAnswer((_) async => Result.error(const ServerFailure('permission denied')));
      expect((await repository().fetchRecent()).data?.map((pick) => pick.wallpaper.id), <String>['wall-good-new']);
      expect(
        ((await cache.read(source: 'wotd', scope: 'archive'))!.payload! as Map<String, dynamic>)['picks'],
        hasLength(1),
      );

      when(
        () => prismRepository.fetchByDocumentId('doc-good'),
      ).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
      final Result<List<WotdPastPick>> afterRestart = await repository().fetchRecent();
      expect(afterRestart.data?.map((pick) => pick.wallpaper.id), <String>['wall-good-new']);
    });

    test('all transient lookup failures reuse the matching durable archive rows', () async {
      final Directory directory = Directory.systemTemp.createTempSync('wotd_all_error_test');
      addTearDown(() => directory.deleteSync(recursive: true));
      final FeedCacheLocalDataSource cache = FeedCacheLocalDataSource(
        store: DurableJsonStore('wotd_all_error_test', directory: directory),
      );
      final FakeDocRow row = (
        id: '2026-01-04',
        data: <String, dynamic>{'wallId': 'doc-a', 'date': DateTime.utc(2026, 1, 4)},
      );
      final _WotdMetadataFirestoreClient client = _WotdMetadataFirestoreClient()..onQuery = (_) => <FakeDocRow>[row];
      when(
        () => prismRepository.fetchByDocumentId('doc-a'),
      ).thenAnswer((_) async => Result.success(_wall('wall-a', documentId: 'doc-a')));
      final blockRepo = FakeUserBlockRepository.pending()..completeInitial(<String>{});
      await WallOfTheDayRepositoryImpl(client, prismRepository, blockRepo, feedCacheLocal: cache).fetchRecent();
      when(
        () => prismRepository.fetchByDocumentId('doc-a'),
      ).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));

      final Result<List<WotdPastPick>> result = await WallOfTheDayRepositoryImpl(
        client,
        prismRepository,
        blockRepo,
        feedCacheLocal: cache,
      ).fetchRecent();

      expect(result.data?.map((pick) => pick.wallpaper.id), <String>['wall-a']);
    });

    test('authoritative lookup failures never reuse the archive', () async {
      final FakeFeedCacheLocalDataSource cache = FakeFeedCacheLocalDataSource();
      final FakeDocRow row = (
        id: '2026-01-04',
        data: <String, dynamic>{'wallId': 'doc-a', 'date': DateTime.utc(2026, 1, 4)},
      );
      final _WotdMetadataFirestoreClient client = _WotdMetadataFirestoreClient()..onQuery = (_) => <FakeDocRow>[row];
      when(
        () => prismRepository.fetchByDocumentId('doc-a'),
      ).thenAnswer((_) async => Result.error(const ServerFailure('permission denied')));
      final repo = WallOfTheDayRepositoryImpl(
        client,
        prismRepository,
        FakeUserBlockRepository.pending()..completeInitial(<String>{}),
        feedCacheLocal: cache,
      );

      expect((await repo.fetchRecent()).isFailure, isTrue);
      expect(cache.snapshots, isEmpty);
    });

    test('cached picks wait for block hydration and exclude a newly blocked creator', () async {
      final FakeFeedCacheLocalDataSource cache = FakeFeedCacheLocalDataSource();
      final FakeDocRow row = (
        id: '2026-01-04',
        data: <String, dynamic>{'wallId': 'doc-a', 'date': DateTime.utc(2026, 1, 4)},
      );
      final _WotdMetadataFirestoreClient client = _WotdMetadataFirestoreClient()..onQuery = (_) => <FakeDocRow>[row];
      when(() => prismRepository.fetchByDocumentId('doc-a')).thenAnswer(
        (_) async => Result.success(
          const PrismWallpaper(
            core: WallpaperCore(
              id: 'wall-a',
              source: WallpaperSource.prism,
              fullUrl: 'https://example.com/wall-a.jpg',
              thumbnailUrl: 'https://example.com/wall-a-thumb.jpg',
              authorEmail: 'creator@example.com',
            ),
            review: true,
            firestoreDocumentId: 'doc-a',
          ),
        ),
      );
      final _DelayedBlockRepository hydratedBlocks = _DelayedBlockRepository();
      final WallOfTheDayRepositoryImpl cachedWriter = WallOfTheDayRepositoryImpl(
        client,
        prismRepository,
        FakeUserBlockRepository.pending()..completeInitial(<String>{}),
        feedCacheLocal: cache,
      );
      await cachedWriter.fetchRecent();
      when(
        () => prismRepository.fetchByDocumentId('doc-a'),
      ).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
      final Future<Result<List<WotdPastPick>>> pending = WallOfTheDayRepositoryImpl(
        client,
        prismRepository,
        hydratedBlocks,
        feedCacheLocal: cache,
      ).fetchRecent();
      var completed = false;
      unawaited(
        pending.then((_) {
          completed = true;
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      hydratedBlocks.snapshot.complete(<String>{'creator@example.com'});

      expect((await pending).data, isEmpty);
      expect(((cache.snapshots['wotd/archive']!.payload! as Map<String, dynamic>)['picks'] as List), hasLength(1));

      when(
        () => prismRepository.fetchByDocumentId('doc-a'),
      ).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
      final Result<List<WotdPastPick>> unblockedRestart = await WallOfTheDayRepositoryImpl(
        client,
        prismRepository,
        FakeUserBlockRepository.pending()..completeInitial(<String>{}),
        feedCacheLocal: cache,
      ).fetchRecent();
      expect(unblockedRestart.data?.single.wallpaper.id, 'wall-a');
    });
  });

  test("today's pick carries the loaded wall, so the detail screen needs no second fetch", () async {
    final wall = _wall('wall-1');
    when(() => prismRepository.fetchByDocumentId('wall-doc-1')).thenAnswer((_) async => Result.success(wall));
    final repo = WallOfTheDayRepositoryImpl(
      firestoreClient,
      prismRepository,
      FakeUserBlockRepository.pending()..completeInitial(<String>{}),
    );

    expect((await repo.fetchToday()).data?.wallpaper, same(wall));
  });
}
