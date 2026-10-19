// ignore_for_file: subtype_of_sealed_class, avoid_implementing_value_types

import 'dart:async';

import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_telemetry.dart';
import 'package:Prism/core/firestore/firestore_tracked_client.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}

class _MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

class _MockQueryDoc extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class _RecordingSink implements FirestoreTelemetrySink {
  final List<FirestoreTelemetryEvent> events = <FirestoreTelemetryEvent>[];

  @override
  Future<void> emit(FirestoreTelemetryEvent event) async {
    events.add(event);
  }
}

QuerySnapshot<Map<String, dynamic>> _snapshot(List<String> ids) {
  final snapshot = _MockQuerySnapshot();
  final docs = ids.map((id) {
    final d = _MockQueryDoc();
    when(() => d.id).thenReturn(id);
    when(() => d.exists).thenReturn(true);
    when(() => d.data()).thenReturn(<String, dynamic>{'id': id});
    return d;
  }).toList();
  when(() => snapshot.docs).thenReturn(docs);
  return snapshot;
}

bool _isCache(GetOptions? o) => o?.source == Source.cache;

final snapA = _snapshot(['a']);
final snapB = _snapshot(['b']);
final snapNet = _snapshot(['net']);
final empty = _snapshot([]);

void main() {
  const spec = FirestoreQuerySpec(
    collection: 'walls',
    sourceTag: 'test.disk_first',
    cachePolicy: FirestoreCachePolicy.diskFirst,
  );

  late _MockCollection collection;
  late _RecordingSink sink;
  late FirestoreTrackedClient client;

  setUpAll(() => registerFallbackValue(const GetOptions()));

  setUp(() {
    final firestore = _MockFirestore();
    collection = _MockCollection();
    sink = _RecordingSink();
    client = FirestoreTrackedClient(firestore, sink);
    when(() => firestore.collection('walls')).thenReturn(collection);
  });

  test('diskFirst returns cached docs without waiting on the server and refreshes in the background', () async {
    final Completer<QuerySnapshot<Map<String, dynamic>>> server = Completer<QuerySnapshot<Map<String, dynamic>>>();
    when(() => collection.get(any(that: predicate<GetOptions?>(_isCache)))).thenAnswer((_) async => snapA);
    when(() => collection.get()).thenAnswer((_) => server.future);

    final List<String> result = await client.query<String>(spec, (data, id) => id);

    expect(result, <String>['a']);
    await Future<void>.delayed(Duration.zero);
    verify(() => collection.get()).called(1);
    expect(sink.events.single.success, isTrue);
    expect(sink.events.single.resultCount, 1);

    server.complete(snapB);
    await Future<void>.delayed(Duration.zero);
    expect(await client.query<String>(spec, (data, id) => id), <String>['b']);
  });

  test('diskFirst falls through to the network when the cache is empty', () async {
    when(() => collection.get(any(that: predicate<GetOptions?>(_isCache)))).thenAnswer((_) async => empty);
    when(() => collection.get()).thenAnswer((_) async => snapNet);

    expect(await client.query<String>(spec, (data, id) => id), <String>['net']);
  });

  test('diskFirst reuses cached docs while the background refresh is pending', () async {
    final server = Completer<QuerySnapshot<Map<String, dynamic>>>();
    when(() => collection.get(any(that: predicate<GetOptions?>(_isCache)))).thenAnswer((_) async => snapA);
    when(() => collection.get()).thenAnswer((_) => server.future);

    expect(await client.query<String>(spec, (data, id) => id), <String>['a']);
    final second = client.query<String>(spec, (data, id) => id);
    var completed = false;
    unawaited(second.then((_) => completed = true));
    await Future<void>.delayed(Duration.zero);

    expect(completed, isTrue, reason: 'A cache hit must not wait for the background server request.');
    expect(await second, <String>['a']);
    server.complete(snapB);
    await Future<void>.delayed(Duration.zero);
  });

  test('concurrent disk cache misses share one network request', () async {
    final disk = Completer<QuerySnapshot<Map<String, dynamic>>>();
    final server = Completer<QuerySnapshot<Map<String, dynamic>>>();
    when(() => collection.get(any(that: predicate<GetOptions?>(_isCache)))).thenAnswer((_) => disk.future);
    when(() => collection.get()).thenAnswer((_) => server.future);

    final first = client.query<String>(spec, (data, id) => id);
    final second = client.query<String>(spec, (data, id) => id);
    disk.complete(empty);
    await Future<void>.delayed(Duration.zero);

    verify(() => collection.get()).called(1);
    server.complete(snapNet);
    expect(await first, <String>['net']);
    expect(await second, <String>['net']);
  });

  test('a slow concurrent disk read does not overwrite a completed server refresh', () async {
    final firstDisk = Completer<QuerySnapshot<Map<String, dynamic>>>();
    final secondDisk = Completer<QuerySnapshot<Map<String, dynamic>>>();
    final server = Completer<QuerySnapshot<Map<String, dynamic>>>();
    var diskReads = 0;
    when(
      () => collection.get(any(that: predicate<GetOptions?>(_isCache))),
    ).thenAnswer((_) => diskReads++ == 0 ? firstDisk.future : secondDisk.future);
    when(() => collection.get()).thenAnswer((_) => server.future);

    final first = client.query<String>(spec, (data, id) => id);
    final second = client.query<String>(spec, (data, id) => id);
    firstDisk.complete(snapA);
    expect(await first, <String>['a']);
    server.complete(snapB);
    await Future<void>.delayed(Duration.zero);
    secondDisk.complete(snapA);

    expect(await second, <String>['b']);
    verify(() => collection.get()).called(1);
  });

  test('diskFirst falls through to the network when the cache read throws', () async {
    when(() => collection.get(any(that: predicate<GetOptions?>(_isCache)))).thenThrow(StateError('no persistence'));
    when(() => collection.get()).thenAnswer((_) async => snapNet);

    expect(await client.query<String>(spec, (data, id) => id), <String>['net']);
  });

  test('a failed background refresh is swallowed', () async {
    when(() => collection.get(any(that: predicate<GetOptions?>(_isCache)))).thenAnswer((_) async => snapA);
    when(() => collection.get()).thenThrow(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));

    expect(await client.query<String>(spec, (data, id) => id), <String>['a']);
    await Future<void>.delayed(Duration.zero);
  });
}
