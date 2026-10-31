// ignore_for_file: subtype_of_sealed_class, avoid_implementing_value_types

import 'dart:async';
import 'dart:io';

import 'package:Prism/core/di/injection_module.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_telemetry.dart';
import 'package:Prism/core/firestore/firestore_tracked_client.dart';
import 'package:Prism/core/monitoring/sentry_before_send.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockDoc extends Mock implements DocumentReference<Map<String, dynamic>> {}

class _MockSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

class _MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

class _MockQueryDoc extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class _MockSnapshotMetadata extends Mock implements SnapshotMetadata {}

class _TestAppModule extends AppModule {}

class _RecordingSink implements FirestoreTelemetrySink {
  final List<FirestoreTelemetryEvent> events = <FirestoreTelemetryEvent>[];

  @override
  Future<void> emit(FirestoreTelemetryEvent event) async {
    events.add(event);
  }
}

FirebaseException _permissionDenied() => FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

void main() {
  test('a document id filter uses FieldPath.documentId', () {
    expect(firestoreQueryField(firestoreDocumentIdField), FieldPath.documentId);
    expect(firestoreQueryField('createdAt'), 'createdAt');
  });

  late _MockFirestore firestore;
  late _MockCollection collection;
  late _MockDoc doc;
  late _RecordingSink sink;
  late FirestoreTrackedClient client;

  setUpAll(() {
    registerFallbackValue(SetOptions(merge: false));
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    firestore = _MockFirestore();
    collection = _MockCollection();
    doc = _MockDoc();
    sink = _RecordingSink();
    client = FirestoreTrackedClient(firestore, sink);
    when(() => firestore.collection('walls')).thenReturn(collection);
    when(() => collection.doc('a')).thenReturn(doc);
  });

  test('reviewed wall queries require fully redacted original provenance', () async {
    final query = _MockQuery();
    final snapshot = _MockQuerySnapshot();
    when(() => collection.where('review', isEqualTo: true)).thenReturn(query);
    when(() => query.where('originalProtected', isEqualTo: true)).thenReturn(query);
    const redactedFields = <String>['wallpaper_url', 'wallpaper_path', 'wallpaper_sha', 'thumb_path', 'thumb_sha'];
    for (final field in redactedFields) {
      when(() => query.where(field, isEqualTo: '')).thenReturn(query);
    }
    when(() => query.get()).thenAnswer((_) async => snapshot);
    when(() => snapshot.docs).thenReturn(<QueryDocumentSnapshot<Map<String, dynamic>>>[]);

    await client.query<String>(
      const FirestoreQuerySpec(
        collection: 'walls',
        sourceTag: 'test.public_redaction',
        filters: <FirestoreFilter>[FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true)],
      ),
      (data, id) => id,
    );

    verify(() => query.where('originalProtected', isEqualTo: true)).called(1);
    for (final field in redactedFields) {
      verify(() => query.where(field, isEqualTo: '')).called(1);
    }
  });

  test('serverOnly uses Source.server and never reuses an earlier result', () async {
    final snapshot = _MockQuerySnapshot();
    when(() => snapshot.docs).thenReturn([]);
    when(() => collection.get(const GetOptions(source: Source.server))).thenAnswer((_) async => snapshot);
    const spec = FirestoreQuerySpec(
      collection: 'walls',
      sourceTag: 'test.canonical',
      cachePolicy: FirestoreCachePolicy.serverOnly,
      dedupeWindowMs: 10000,
    );
    expect(await client.query<String>(spec, (_, id) => id), isEmpty);
    expect(await client.query<String>(spec, (_, id) => id), isEmpty);
    verify(() => collection.get(const GetOptions(source: Source.server))).called(2);
    verifyNever(() => collection.get());
  });

  test('deferred Firestore access does not happen while constructing the client', () async {
    var factoryCalls = 0;
    final deferredClient = FirestoreTrackedClient.deferred(
      () {
        factoryCalls++;
        throw StateError('Firestore setup failed');
      },
      sink,
      waitUntilReady: () async => true,
    );

    expect(factoryCalls, 0);
    await expectLater(
      deferredClient.query<String>(
        const FirestoreQuerySpec(collection: 'walls', sourceTag: 'test.offline'),
        (data, id) => id,
      ),
      throwsA(isA<FirestoreError>()),
    );
    expect(factoryCalls, 1);
    expect(sink.events.single.sourceTag, 'test.offline');
    expect(sink.events.single.success, isFalse);
  });

  test('the DI Firestore client can be constructed without a Firebase app', () async {
    final client = _TestAppModule().firestoreClient(sink);

    await expectLater(
      client.query<String>(
        const FirestoreQuerySpec(collection: 'walls', sourceTag: 'test.no_firebase_app'),
        (data, id) => id,
      ),
      throwsA(isA<FirestoreError>()),
    );
    expect(sink.events.single.sourceTag, 'test.no_firebase_app');
    expect(sink.events.single.success, isFalse);
  });

  test('watchQueryWithMetadata defers Firestore setup and reports setup failures through the stream', () async {
    var factoryCalls = 0;
    final deferredClient = FirestoreTrackedClient.deferred(
      () {
        factoryCalls++;
        throw StateError('Firestore setup failed');
      },
      sink,
      waitUntilReady: () async => true,
    );

    final Stream<({List<String> items, bool isFromCache})> stream = deferredClient.watchQueryWithMetadata<String>(
      const FirestoreQuerySpec(collection: 'walls', sourceTag: 'test.watch_offline', isStream: true),
      (data, id) => id,
    );

    expect(factoryCalls, 0);
    await expectLater(stream, emitsError(isA<FirestoreError>()));

    expect(factoryCalls, 1);
    expect(sink.events, hasLength(1));
    expect(sink.events.single.operation, FirestoreOperation.streamSubscribe);
    expect(sink.events.single.sourceTag, 'test.watch_offline');
    expect(sink.events.single.success, isFalse);
  });

  test('watchQueryWithMetadata includes metadata changes and preserves cancellation', () async {
    var cancelled = false;
    final StreamController<QuerySnapshot<Map<String, dynamic>>> snapshots =
        StreamController<QuerySnapshot<Map<String, dynamic>>>(onCancel: () => cancelled = true);
    when(() => collection.snapshots(includeMetadataChanges: true)).thenAnswer((_) => snapshots.stream);

    final cacheSnapshot = _MockQuerySnapshot();
    final cacheMetadata = _MockSnapshotMetadata();
    when(() => cacheSnapshot.docs).thenReturn(<QueryDocumentSnapshot<Map<String, dynamic>>>[]);
    when(() => cacheSnapshot.metadata).thenReturn(cacheMetadata);
    when(() => cacheMetadata.isFromCache).thenReturn(true);

    final serverSnapshot = _MockQuerySnapshot();
    final serverMetadata = _MockSnapshotMetadata();
    when(() => serverSnapshot.docs).thenReturn(<QueryDocumentSnapshot<Map<String, dynamic>>>[]);
    when(() => serverSnapshot.metadata).thenReturn(serverMetadata);
    when(() => serverMetadata.isFromCache).thenReturn(false);

    final Stream<({List<String> items, bool isFromCache})> stream = client.watchQueryWithMetadata<String>(
      const FirestoreQuerySpec(collection: 'walls', sourceTag: 'test.watch_metadata', isStream: true),
      (data, id) => id,
    );

    final Future<void> expectation = expectLater(
      stream,
      emitsInOrder(<Matcher>[
        isA<({List<String> items, bool isFromCache})>()
            .having((record) => record.items, 'items', isEmpty)
            .having((record) => record.isFromCache, 'isFromCache', isTrue),
        isA<({List<String> items, bool isFromCache})>()
            .having((record) => record.items, 'items', isEmpty)
            .having((record) => record.isFromCache, 'isFromCache', isFalse),
      ]),
    );
    snapshots
      ..add(cacheSnapshot)
      ..add(serverSnapshot);
    await expectation;
    verify(() => collection.snapshots(includeMetadataChanges: true)).called(1);
    expect(cancelled, isTrue);
  });

  test('query maps document id range filters and order without treating __name__ as a data field', () async {
    final _MockQuery query = _MockQuery();
    final _MockQuerySnapshot snapshot = _MockQuerySnapshot();
    final DateTime rangeStart = DateTime.utc(2026);
    when(() => collection.where(FieldPath.documentId, isGreaterThanOrEqualTo: 'a')).thenReturn(query);
    when(() => query.where(FieldPath.documentId, isLessThanOrEqualTo: 'z')).thenReturn(query);
    when(() => query.where('createdAt', isGreaterThan: rangeStart)).thenReturn(query);
    when(() => query.orderBy(FieldPath.documentId, descending: true)).thenReturn(query);
    when(() => query.get()).thenAnswer((_) async => snapshot);
    when(() => snapshot.docs).thenReturn(<QueryDocumentSnapshot<Map<String, dynamic>>>[]);

    await client.query<String>(
      FirestoreQuerySpec(
        collection: 'walls',
        sourceTag: 'test.document-id-range',
        filters: <FirestoreFilter>[
          const FirestoreFilter(
            field: firestoreDocumentIdField,
            op: FirestoreFilterOp.isGreaterThanOrEqualTo,
            value: 'a',
          ),
          const FirestoreFilter(field: firestoreDocumentIdField, op: FirestoreFilterOp.isLessThanOrEqualTo, value: 'z'),
          FirestoreFilter(field: 'createdAt', op: FirestoreFilterOp.isGreaterThan, value: rangeStart),
        ],
        orderBy: <FirestoreOrderBy>[const FirestoreOrderBy(field: firestoreDocumentIdField, descending: true)],
      ),
      (data, id) => id,
    );

    verify(() => collection.where(FieldPath.documentId, isGreaterThanOrEqualTo: 'a')).called(1);
    verify(() => query.where(FieldPath.documentId, isLessThanOrEqualTo: 'z')).called(1);
    verify(() => query.where('createdAt', isGreaterThan: rangeStart)).called(1);
    verify(() => query.orderBy(FieldPath.documentId, descending: true)).called(1);
    verifyNever(() => collection.where('__name__', isGreaterThanOrEqualTo: 'a'));
    verifyNever(() => query.where('__name__', isLessThanOrEqualTo: 'z'));
    verifyNever(() => query.orderBy('__name__', descending: true));
  });

  test('watchQuery surfaces a stream failure as FirestoreError and records it', () async {
    when(
      () => collection.snapshots(includeMetadataChanges: false),
    ).thenAnswer((_) => Stream<QuerySnapshot<Map<String, dynamic>>>.error(_permissionDenied()));

    final Stream<List<String>> stream = client.watchQuery<String>(
      const FirestoreQuerySpec(collection: 'walls', sourceTag: 'test.watch', isStream: true),
      (data, id) => id,
    );

    await expectLater(stream, emitsError(isA<FirestoreError>().having((e) => e.code, 'code', 'permission-denied')));
    final FirestoreTelemetryEvent failure = sink.events.last;
    expect(failure.operation, FirestoreOperation.streamSubscribe);
    expect(failure.success, isFalse);
    expect(failure.errorCode, 'permission-denied');
    verify(() => collection.snapshots(includeMetadataChanges: false)).called(1);
  });

  test('a failed stale-while-revalidate refresh is recorded and does not escape as an unhandled error', () async {
    final snapshot = _MockQuerySnapshot();
    when(() => snapshot.docs).thenReturn(<QueryDocumentSnapshot<Map<String, dynamic>>>[]);
    var calls = 0;
    when(() => collection.get()).thenAnswer((_) async {
      if (++calls == 1) return snapshot;
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    });
    const spec = FirestoreQuerySpec(
      collection: 'walls',
      sourceTag: 'test.swr',
      cachePolicy: FirestoreCachePolicy.staleWhileRevalidate,
    );

    await client.query<String>(spec, (data, id) => id);
    expect(await client.query<String>(spec, (data, id) => id), isEmpty);
    await pumpEventQueue();

    expect(calls, 2);
    expect(sink.events.last.success, isFalse);
    expect(sink.events.last.errorCode, 'unavailable');
  });

  test('setDoc emits success telemetry with the doc id', () async {
    when(() => doc.set(any(), any())).thenAnswer((_) async {});

    await client.setDoc('walls', 'a', <String, dynamic>{'x': 1}, sourceTag: 'test.set');

    final FirestoreTelemetryEvent event = sink.events.single;
    expect(event.operation, FirestoreOperation.set);
    expect(event.sourceTag, 'test.set');
    expect(event.docId, 'a');
    expect(event.success, isTrue);
  });

  test('metadata invalidation does not let an older in-flight query restore stale memory data', () async {
    final oldSnapshot = _MockQuerySnapshot();
    final newSnapshot = _MockQuerySnapshot();
    final oldDoc = _MockQueryDoc();
    final newDoc = _MockQueryDoc();
    when(() => oldDoc.id).thenReturn('a');
    when(() => newDoc.id).thenReturn('a');
    when(() => oldDoc.exists).thenReturn(true);
    when(() => newDoc.exists).thenReturn(true);
    when(() => oldDoc.data()).thenReturn({'title': 'Old title'});
    when(() => newDoc.data()).thenReturn({'title': 'New title'});
    when(() => oldSnapshot.docs).thenReturn([oldDoc]);
    when(() => newSnapshot.docs).thenReturn([newDoc]);
    final oldRequest = Completer<QuerySnapshot<Map<String, dynamic>>>();
    var calls = 0;
    when(() => collection.get()).thenAnswer((_) async => ++calls == 1 ? await oldRequest.future : newSnapshot);
    const spec = FirestoreQuerySpec(
      collection: 'walls',
      sourceTag: 'test.metadata.invalidate',
      cachePolicy: FirestoreCachePolicy.memoryFirst,
    );
    final oldRead = client.query<String>(spec, (data, _) => data['title'] as String);
    await pumpEventQueue();
    client.invalidateQueryCache();
    expect(await client.query<String>(spec, (data, _) => data['title'] as String), ['New title']);
    oldRequest.complete(oldSnapshot);
    expect(await oldRead, ['Old title']);
    expect(await client.query<String>(spec, (data, _) => data['title'] as String), ['New title']);
    expect(calls, 2);
  });

  test('updateDoc maps a failure to FirestoreError and emits failure telemetry', () async {
    when(() => doc.update(any())).thenThrow(_permissionDenied());

    await expectLater(
      client.updateDoc('walls', 'a', <String, dynamic>{'x': 1}, sourceTag: 'test.update'),
      throwsA(isA<FirestoreError>().having((e) => e.code, 'code', 'permission-denied')),
    );

    final FirestoreTelemetryEvent event = sink.events.single;
    expect(event.operation, FirestoreOperation.update);
    expect(event.success, isFalse);
    expect(event.errorCode, 'permission-denied');
  });

  test('getById reports a hit count and returns null for a missing doc', () async {
    final _MockSnapshot snapshot = _MockSnapshot();
    when(() => snapshot.exists).thenReturn(false);
    when(() => doc.get()).thenAnswer((_) async => snapshot);

    final String? result = await client.getById<String>('walls', 'a', (data, id) => id, sourceTag: 'test.get');

    expect(result, isNull);
    expect(sink.events.single.operation, FirestoreOperation.docGet);
    expect(sink.events.single.resultCount, 0);
  });

  test('getById returns a cache-first hit without making a network read', () async {
    final _MockSnapshot snapshot = _MockSnapshot();
    when(() => snapshot.exists).thenReturn(true);
    when(() => snapshot.data()).thenReturn(<String, dynamic>{'name': 'cached'});
    when(() => snapshot.id).thenReturn('a');
    when(() => doc.get(const GetOptions(source: Source.cache))).thenAnswer((_) async => snapshot);

    final String? name = await client.getById<String>(
      'walls',
      'a',
      (data, id) => '${data['name']}:$id',
      sourceTag: 'test.cache-hit',
      preferCacheFirst: true,
    );

    expect(name, 'cached:a');
    expect(sink.events.single.success, isTrue);
    verify(() => doc.get(const GetOptions(source: Source.cache))).called(1);
    verifyNever(() => doc.get());
  });

  test('getById falls back to the network when the local cache is unavailable', () async {
    final _MockSnapshot snapshot = _MockSnapshot();
    when(() => doc.get(const GetOptions(source: Source.cache))).thenThrow(StateError('cache unavailable'));
    when(() => snapshot.exists).thenReturn(true);
    when(() => snapshot.data()).thenReturn(<String, dynamic>{'name': 'server'});
    when(() => snapshot.id).thenReturn('a');
    when(() => doc.get()).thenAnswer((_) async => snapshot);

    final String? name = await client.getById<String>(
      'walls',
      'a',
      (data, id) => '${data['name']}:$id',
      sourceTag: 'test.cache-fallback',
      preferCacheFirst: true,
    );

    expect(name, 'server:a');
    expect(sink.events.single.success, isTrue);
    verify(() => doc.get()).called(1);
  });

  test('query adapts document-ID filters to FieldPath.documentId', () async {
    final _MockQuery query = _MockQuery();
    final _MockQuerySnapshot snapshot = _MockQuerySnapshot();
    when(() => firestore.collection('drawTickets')).thenReturn(collection);
    when(() => collection.where(FieldPath.documentId, isEqualTo: '2026-W42_u1')).thenReturn(query);
    when(() => query.where('uid', isEqualTo: 'u1')).thenReturn(query);
    when(() => query.get()).thenAnswer((_) async => snapshot);
    when(() => snapshot.docs).thenReturn(<QueryDocumentSnapshot<Map<String, dynamic>>>[]);

    await client.query<String>(
      const FirestoreQuerySpec(
        collection: 'drawTickets',
        sourceTag: 'test.document_id_filter',
        filters: <FirestoreFilter>[
          FirestoreFilter(field: firestoreDocumentIdField, op: FirestoreFilterOp.isEqualTo, value: '2026-W42_u1'),
          FirestoreFilter(field: 'uid', op: FirestoreFilterOp.isEqualTo, value: 'u1'),
        ],
      ),
      (data, id) => id,
    );

    verify(() => collection.where(FieldPath.documentId, isEqualTo: '2026-W42_u1')).called(1);
    verify(() => query.where('uid', isEqualTo: 'u1')).called(1);
  });

  test('runBatch failure is mapped and recorded under an empty collection', () async {
    final WriteBatch batch = _MockBatch();
    when(() => firestore.batch()).thenReturn(batch);
    when(() => batch.commit()).thenThrow(_permissionDenied());

    await expectLater(client.runBatch((b) async {}, sourceTag: 'test.batch'), throwsA(isA<FirestoreError>()));

    expect(sink.events.single.collection, '');
    expect(sink.events.single.success, isFalse);
  });

  test('deferred client waits for Firebase readiness before the first read', () async {
    final Completer<bool> ready = Completer<bool>();
    var factoryCalls = 0;
    final deferredClient = FirestoreTrackedClient.deferred(
      () {
        factoryCalls++;
        return firestore;
      },
      sink,
      waitUntilReady: () => ready.future,
    );
    final snapshot = _MockSnapshot();
    when(() => snapshot.exists).thenReturn(true);
    when(() => snapshot.id).thenReturn('a');
    when(() => snapshot.data()).thenReturn(<String, dynamic>{'name': 'x'});
    when(() => doc.get()).thenAnswer((_) async => snapshot);

    final Future<String?> result = deferredClient.getById<String>(
      'walls',
      'a',
      (data, id) => '${data['name']}:$id',
      sourceTag: 'test.ready',
    );
    await Future<void>.delayed(Duration.zero);
    expect(factoryCalls, 0);

    ready.complete(true);

    expect(await result, 'x:a');
    expect(sink.events.single.success, isTrue);
  });

  test('deferred client watchQuery subscribes only after Firebase is ready', () async {
    final Completer<bool> ready = Completer<bool>();
    var factoryCalls = 0;
    final deferredClient = FirestoreTrackedClient.deferred(
      () {
        factoryCalls++;
        return firestore;
      },
      sink,
      waitUntilReady: () => ready.future,
    );
    final snapshots = StreamController<QuerySnapshot<Map<String, dynamic>>>();
    final emptySnapshot = _MockQuerySnapshot();
    final metadata = _MockSnapshotMetadata();
    when(() => emptySnapshot.docs).thenReturn(<QueryDocumentSnapshot<Map<String, dynamic>>>[]);
    when(() => emptySnapshot.metadata).thenReturn(metadata);
    when(() => metadata.isFromCache).thenReturn(false);
    when(() => collection.snapshots(includeMetadataChanges: false)).thenAnswer((_) => snapshots.stream);

    final Future<List<String>> first = deferredClient
        .watchQuery<String>(
          const FirestoreQuerySpec(collection: 'walls', sourceTag: 'test.watch_ready', isStream: true),
          (data, id) => id,
        )
        .first;
    await Future<void>.delayed(Duration.zero);
    expect(factoryCalls, 0);

    ready.complete(true);
    await Future<void>.delayed(Duration.zero);
    snapshots.add(emptySnapshot);

    expect(await first, isEmpty);
    await snapshots.close();
  });

  test('telemetry durationMs excludes the readiness wait', () async {
    final Completer<bool> ready = Completer<bool>();
    final deferredClient = FirestoreTrackedClient.deferred(() => firestore, sink, waitUntilReady: () => ready.future);
    final snapshot = _MockSnapshot();
    when(() => snapshot.exists).thenReturn(false);
    when(() => doc.get()).thenAnswer((_) async => snapshot);

    final Future<String?> result = deferredClient.getById<String>(
      'walls',
      'a',
      (data, id) => id,
      sourceTag: 'test.duration',
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
    ready.complete(true);
    await result;

    expect(sink.events.single.durationMs, lessThan(100));
  });

  test('failed initialization closes a stream with an error without accessing Firestore', () async {
    var factoryCalls = 0;
    when(() => collection.snapshots(includeMetadataChanges: false)).thenAnswer((_) => const Stream.empty());
    final deferredClient = FirestoreTrackedClient.deferred(
      () {
        factoryCalls++;
        return firestore;
      },
      sink,
      waitUntilReady: () async => false,
    );

    await expectLater(
      deferredClient.watchQuery<String>(
        const FirestoreQuerySpec(collection: 'walls', sourceTag: 'test.init_failed', isStream: true),
        (_, id) => id,
      ),
      emitsInOrder(<Object>[
        emitsError(isA<FirestoreError>().having((error) => error.code, 'code', 'unavailable')),
        emitsDone,
      ]),
    );
    expect(factoryCalls, 0);
    expect(sink.events.map((event) => (event.success, event.errorCode)), <(bool, String?)>[(false, 'unavailable')]);
  });

  test('failed initialization fails a one-shot read as unavailable without accessing Firestore', () async {
    var factoryCalls = 0;
    final deferredClient = FirestoreTrackedClient.deferred(
      () {
        factoryCalls++;
        throw FirebaseException(plugin: 'core', code: 'no-app');
      },
      sink,
      waitUntilReady: () async => false,
    );

    for (final bool preferCacheFirst in <bool>[false, true]) {
      await expectLater(
        deferredClient.getById<String>(
          'usersv2',
          'u1',
          (_, id) => id,
          sourceTag: 'test.init_failed_read',
          preferCacheFirst: preferCacheFirst,
        ),
        throwsA(
          isA<FirestoreError>()
              .having((error) => error.code, 'code', 'unavailable')
              .having(isNetworkNoise, 'isNetworkNoise', isTrue),
        ),
      );
    }
    expect(factoryCalls, 0);
    expect(sink.events.map((event) => (event.success, event.errorCode)), <(bool, String?)>[
      (false, 'unavailable'),
      (false, 'unavailable'),
    ]);
  });

  test('cancelling before initialization completes promptly and does not attach a listener later', () async {
    final ready = Completer<bool>();
    var factoryCalls = 0;
    final snapshots = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
    final snapshot = _MockQuerySnapshot();
    final document = _MockQueryDoc();
    final metadata = _MockSnapshotMetadata();
    when(() => document.id).thenReturn('kept-creator');
    when(() => document.data()).thenReturn(<String, dynamic>{});
    when(() => snapshot.docs).thenReturn(<QueryDocumentSnapshot<Map<String, dynamic>>>[document]);
    when(() => snapshot.metadata).thenReturn(metadata);
    when(() => metadata.isFromCache).thenReturn(false);
    when(() => collection.snapshots(includeMetadataChanges: false)).thenAnswer((_) => snapshots.stream);
    final deferredClient = FirestoreTrackedClient.deferred(
      () {
        factoryCalls++;
        return firestore;
      },
      sink,
      waitUntilReady: () => ready.future,
    );
    const spec = FirestoreQuerySpec(collection: 'walls', sourceTag: 'test.cancel_pending', isStream: true);
    final watch = deferredClient
        .watchQuery<String>(spec, (_, id) => id)
        .listen(
          (_) => fail('A cancelled watch must not receive data.'),
          onError: (Object error) => fail('A cancelled watch must not receive errors: $error'),
        );
    await Future<void>.delayed(Duration.zero);
    await watch.cancel().timeout(const Duration(seconds: 1));
    expect(ready.isCompleted, isFalse);
    ready.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(factoryCalls, 0);
    expect(snapshots.hasListener, isFalse);
    expect(sink.events, isEmpty);

    final next = deferredClient.watchQuery<String>(spec, (_, id) => id).first;
    await Future<void>.delayed(Duration.zero);
    snapshots.add(snapshot);
    expect(await next, <String>['kept-creator']);
    expect(factoryCalls, 1);
    expect(sink.events.map((event) => event.success), <bool>[true]);
    expect(snapshots.hasListener, isFalse);
    await snapshots.close();
  });

  testWidgets('production readiness keeps streams alive beyond the bounded read wait and cancels pending watches', (
    tester,
  ) async {
    final ready = Completer<bool>();
    FirebaseInit.setFuture(ready.future);
    var factoryCalls = 0;
    var cancelledFactoryCalls = 0;
    var readFactoryCalls = 0;
    var initialized = false;
    final snapshots = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
    final snapshot = _MockQuerySnapshot();
    final document = _MockQueryDoc();
    final metadata = _MockSnapshotMetadata();
    when(() => document.id).thenReturn('blocked-creator');
    when(() => document.data()).thenReturn(<String, dynamic>{'name': 'Ada'});
    when(() => snapshot.docs).thenReturn(<QueryDocumentSnapshot<Map<String, dynamic>>>[document]);
    when(() => snapshot.metadata).thenReturn(metadata);
    when(() => metadata.isFromCache).thenReturn(false);
    when(() => collection.snapshots(includeMetadataChanges: false)).thenAnswer((_) => snapshots.stream);
    when(() => collection.snapshots(includeMetadataChanges: true)).thenAnswer((_) => snapshots.stream);

    final deferredClient = FirestoreTrackedClient.deferred(() {
      factoryCalls++;
      if (!initialized) throw FirebaseException(plugin: 'core', code: 'no-app');
      return firestore;
    }, sink);
    final cancelledClient = FirestoreTrackedClient.deferred(() {
      cancelledFactoryCalls++;
      return firestore;
    }, sink);
    final boundedClient = FirestoreTrackedClient.deferred(() {
      readFactoryCalls++;
      throw FirebaseException(plugin: 'core', code: 'no-app');
    }, _RecordingSink());
    const spec = FirestoreQuerySpec(collection: 'walls', sourceTag: 'test.delayed_init', isStream: true);
    final values = <List<String>>[];
    final metadataValues = <({List<String> items, bool isFromCache})>[];
    final errors = <Object>[];
    final watch = deferredClient
        .watchQuery<String>(spec, (data, id) => '${data['name']}:$id')
        .listen(values.add, onError: errors.add);
    final metadataWatch = deferredClient
        .watchQueryWithMetadata<String>(spec, (_, id) => id)
        .listen(metadataValues.add, onError: errors.add);
    final cancelledWatch = cancelledClient
        .watchQuery<String>(spec, (_, id) => id)
        .listen((_) => fail('A cancelled watch must not receive snapshots.'), onError: errors.add);
    FirestoreError? readError;
    unawaited(
      boundedClient
          .query<String>(spec, (_, id) => id)
          .then<void>(
            (_) => fail('The bounded read must fail before Firebase becomes ready.'),
            onError: (Object error) {
              readError = error as FirestoreError;
            },
          ),
    );
    await tester.pump();
    unawaited(cancelledWatch.cancel());
    await tester.pump();

    await tester.pump(const Duration(seconds: 4));
    expect(factoryCalls, 0);
    expect(cancelledFactoryCalls, 0);
    expect(snapshots.hasListener, isFalse);
    expect(errors, isEmpty);
    expect(readError?.code, 'unavailable');
    expect(readFactoryCalls, 0);

    initialized = true;
    ready.complete(true);
    await tester.pump();
    snapshots.add(snapshot);
    await tester.pump();
    expect(values, <List<String>>[
      <String>['Ada:blocked-creator'],
    ]);
    expect(metadataValues.single.items, <String>['blocked-creator']);
    expect(metadataValues.single.isFromCache, isFalse);
    expect(errors, isEmpty);
    expect(factoryCalls, 2);
    expect(cancelledFactoryCalls, 0);
    expect(sink.events.map((event) => event.success), <bool>[true, true]);

    unawaited(watch.cancel());
    unawaited(metadataWatch.cancel());
    unawaited(snapshots.close());
    await tester.pump();
    expect(snapshots.hasListener, isFalse);
  });

  group('FirestoreOperation', () {
    test('splits into reads and writes', () {
      expect(FirestoreOperation.values.where((op) => op.isRead), <FirestoreOperation>[
        FirestoreOperation.queryGet,
        FirestoreOperation.docGet,
        FirestoreOperation.streamSubscribe,
      ]);
      expect(FirestoreOperation.set.isWrite, isTrue);
      expect(FirestoreOperation.transaction.isWrite, isTrue);
    });
  });

  group('trimTelemetryFile', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('telemetry_trim'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('keeps the newer half of the lines once past the cap', () {
      final File file = File('${dir.path}/t.ndjson')
        ..writeAsStringSync('${List.generate(10, (i) => 'l$i').join('\n')}\n');

      trimTelemetryFile(file, maxBytes: 5);

      expect(file.readAsLinesSync(), <String>['l5', 'l6', 'l7', 'l8', 'l9']);
    });

    test('leaves a small file untouched', () {
      final File file = File('${dir.path}/t.ndjson')..writeAsStringSync('a\nb\n');

      trimTelemetryFile(file, maxBytes: 1024);

      expect(file.readAsStringSync(), 'a\nb\n');
    });
  });
}

class _MockBatch extends Mock implements WriteBatch {}
