// ignore_for_file: subtype_of_sealed_class, avoid_implementing_value_types

import 'dart:io';

import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_telemetry.dart';
import 'package:Prism/core/firestore/firestore_tracked_client.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockDoc extends Mock implements DocumentReference<Map<String, dynamic>> {}

class _MockSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

class _MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

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
      () => collection.snapshots(),
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

  test('runBatch failure is mapped and recorded under an empty collection', () async {
    final WriteBatch batch = _MockBatch();
    when(() => firestore.batch()).thenReturn(batch);
    when(() => batch.commit()).thenThrow(_permissionDenied());

    await expectLater(client.runBatch((b) async {}, sourceTag: 'test.batch'), throwsA(isA<FirestoreError>()));

    expect(sink.events.single.collection, '');
    expect(sink.events.single.success, isFalse);
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
