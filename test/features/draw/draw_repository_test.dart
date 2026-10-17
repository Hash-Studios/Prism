import 'dart:async';
import 'dart:io';

import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/draw/data/repositories/draw_repository_impl.dart';
import 'package:Prism/features/draw/domain/entities/draw_entity.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

class _NeverCompletingQueryClient extends FakeFirestoreClient {
  @override
  Stream<({List<T> items, bool isFromCache})> watchQueryWithMetadata<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  ) => Stream<({List<T> items, bool isFromCache})>.empty();
}

class _NeverCompletingTicketClient extends FakeFirestoreClient {
  @override
  Stream<({List<T> items, bool isFromCache})> watchQueryWithMetadata<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  ) => Stream<({List<T> items, bool isFromCache})>.empty();
}

class _MetadataFirestoreClient extends FakeFirestoreClient {
  @override
  Stream<({List<T> items, bool isFromCache})> watchQueryWithMetadata<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  ) async* {
    yield (items: <T>[], isFromCache: true);
    yield (items: await query<T>(spec, map), isFromCache: false);
  }

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    querySpecs.add(spec);
    if (queryError case final Object error) throw error;
    final FirestoreFilter? idFilter = spec.filters
        .where((FirestoreFilter filter) => filter.field == firestoreDocumentIdField)
        .firstOrNull;
    if (idFilter != null) {
      final String id = idFilter.value! as String;
      final Map<String, dynamic>? data = docs[spec.collection]?[id];
      return data == null ? <T>[] : <T>[map(data, id)];
    }
    return (onQuery?.call(spec) ?? const <FakeDocRow>[])
        .map((FakeDocRow row) => map(row.data, row.id))
        .toList(growable: false);
  }
}

class _BlockingTicketStore extends DurableJsonStore {
  _BlockingTicketStore(Directory directory) : super('draws', directory: directory);

  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> allowWrite = Completer<void>();
  bool _blocked = false;

  @override
  Future<void> write(String key, Map<String, Object?> value) async {
    if (key.startsWith('tickets:') && !_blocked) {
      _blocked = true;
      writeStarted.complete();
      await allowWrite.future;
    }
    await super.write(key, value);
  }
}

void main() {
  late FakeFirestoreClient firestore;
  late DrawRepositoryImpl repository;
  late Directory directory;

  setUp(() {
    firestore = _MetadataFirestoreClient();
    directory = Directory.systemTemp.createTempSync('prism-draw-test');
    repository = DrawRepositoryImpl(firestore, store: DurableJsonStore('draws', directory: directory));
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'u1'
      ..loggedIn = true;
  });

  tearDown(() {
    app_state.prismUser = app_constants.createGuestPrismUser();
    directory.deleteSync(recursive: true);
  });

  test('fetchCurrent maps the draw doc with epoch ms times', () async {
    firestore.docs['draws'] = <String, Map<String, dynamic>>{
      '2026-W42': <String, dynamic>{
        'weekKey': '2026-W42',
        'status': 'open',
        'closesAt': DateTime.utc(2026, 10, 19).millisecondsSinceEpoch,
        'tickets': 23,
        'participants': 9,
        'prize': <String, dynamic>{'proMonths': 1, 'itemId': 'frame_prism'},
      },
    };

    final DrawEntity draw = (await repository.fetchCurrent('2026-W42')).data!;

    expect(draw.closesAt, DateTime.utc(2026, 10, 19));
    expect(
      (draw.status, draw.tickets, draw.participants, draw.prizeProMonths, draw.prizeItemId, draw.winnerName),
      ('open', 23, 9, 1, 'frame_prism', null),
    );
  });

  test('a missing draw doc is an open draw with zero tickets', () async {
    final DrawEntity draw = (await repository.fetchCurrent('2026-W42')).data!;

    expect((draw.weekKey, draw.status, draw.tickets, draw.participants), ('2026-W42', 'open', 0, 0));
    expect(draw.closesAt.isAfter(DateTime.now()), isTrue);
  });

  test('fetchLastSettled asks for the newest settled draw', () async {
    firestore.onQuery = (_) => <FakeDocRow>[
      (
        id: '2026-W41',
        data: <String, dynamic>{'status': 'settled', 'winnerName': 'Ana', 'closesAt': 1, 'settledAt': 2},
      ),
    ];

    final DrawEntity? last = (await repository.fetchLastSettled()).data;

    expect(last!.winnerName, 'Ana');
    final FirestoreQuerySpec spec = firestore.querySpecs.single;
    expect(spec.sourceTag, 'draw.last');
    expect(spec.filters.single.value, 'settled');
    expect((spec.orderBy.single.field, spec.orderBy.single.descending, spec.limit), ('settledAt', true, 1));
  });

  test('fetchLastSettled is null when nothing settled', () async {
    expect((await repository.fetchLastSettled()).data, isNull);
  });

  test('fetchMyTickets reads the ticket doc and defaults to zero', () async {
    expect((await repository.fetchMyTickets('2026-W42', 'u1')).data, 0);
    final FirestoreQuerySpec spec = firestore.querySpecs.last;
    expect(spec.collection, 'drawTickets');
    expect(spec.filters.map((filter) => (filter.field, filter.op, filter.value)), <Object>[
      (firestoreDocumentIdField, FirestoreFilterOp.isEqualTo, '2026-W42_u1'),
      ('uid', FirestoreFilterOp.isEqualTo, 'u1'),
    ]);
    expect(spec.limit, 1);
    firestore.docs['drawTickets'] = <String, Map<String, dynamic>>{
      '2026-W42_u1': <String, dynamic>{'uid': 'u1', 'count': 3},
    };
    expect((await repository.fetchMyTickets('2026-W42', 'u1')).data, 3);
  });

  test('a read error becomes a failure', () async {
    firestore.queryError = StateError('boom');
    expect((await repository.fetchLastSettled()).isFailure, isTrue);
  });

  test('settled snapshot survives restart for transient errors, but authoritative empty clears it', () async {
    firestore.onQuery = (_) => [
      (id: '2026-W41', data: <String, dynamic>{'status': 'settled', 'winnerName': 'Ana', 'closesAt': 1}),
    ];
    expect((await repository.fetchLastSettled()).data!.winnerName, 'Ana');

    final FakeFirestoreClient offline = _MetadataFirestoreClient()
      ..queryError = FirestoreError(code: 'unavailable', message: 'offline');
    final DrawRepositoryImpl restarted = DrawRepositoryImpl(
      offline,
      store: DurableJsonStore('draws', directory: directory),
      readTimeout: const Duration(milliseconds: 5),
    );
    expect((await restarted.fetchLastSettled()).data!.winnerName, 'Ana');

    final DrawRepositoryImpl authoritative = DrawRepositoryImpl(
      _MetadataFirestoreClient(),
      store: DurableJsonStore('draws', directory: directory),
    );
    expect((await authoritative.fetchLastSettled()).data, isNull);
    final FakeFirestoreClient laterOffline = _MetadataFirestoreClient()
      ..queryError = FirestoreError(code: 'unavailable', message: 'offline');
    expect(
      (await DrawRepositoryImpl(
        laterOffline,
        store: DurableJsonStore('draws', directory: directory),
      ).fetchLastSettled()).isFailure,
      isTrue,
    );
  });

  test('ticket snapshots are owner scoped and clearForUser removes them', () async {
    firestore.docs['drawTickets'] = <String, Map<String, dynamic>>{
      '2026-W42_u1': <String, dynamic>{'count': 4},
    };
    expect(await repository.fetchMyTickets('2026-W42', 'u1').then((result) => result.data), 4);
    expect(await DurableJsonStore('draws', directory: directory).read('tickets:u1'), isNotNull);
    final DurableJsonStore store = DurableJsonStore('draws', directory: directory);
    final DrawRepositoryImpl timedOut = DrawRepositoryImpl(
      _NeverCompletingTicketClient(),
      store: store,
      readTimeout: const Duration(milliseconds: 1),
    );
    expect((await timedOut.fetchMyTickets('2026-W42', 'u1')).data, 4);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'u2'
      ..loggedIn = true;
    expect((await repository.fetchMyTickets('2026-W42', 'u1')).isFailure, isTrue);
    await DrawRepositoryImpl.clearForUser('u1', store: store);
    expect(await store.read('tickets:u1'), isNull);
  });

  test('clear is serialized with ticket writes and preserves a newer same-owner read', () async {
    firestore.docs['drawTickets'] = <String, Map<String, dynamic>>{
      '2026-W42_u1': <String, dynamic>{'count': 4},
    };
    final _BlockingTicketStore store = _BlockingTicketStore(directory);
    final DrawRepositoryImpl racing = DrawRepositoryImpl(firestore, store: store);

    final Future<Result<int>> oldRead = racing.fetchMyTickets('2026-W42', 'u1');
    await store.writeStarted.future;
    final Future<void> clearing = DrawRepositoryImpl.clearForUser('u1', store: store);
    firestore.docs['drawTickets']!['2026-W42_u1'] = <String, dynamic>{'count': 9};
    final Future<Result<int>> newRead = racing.fetchMyTickets('2026-W42', 'u1');
    store.allowWrite.complete();

    expect((await oldRead).isFailure, isTrue);
    await clearing;
    expect((await newRead).data, 9);
    expect((await store.read('tickets:u1'))?['count'], 9);
  });

  test('repository timeout falls back to the saved settled read', () async {
    firestore.onQuery = (_) => [
      (id: '2026-W41', data: <String, dynamic>{'status': 'settled', 'winnerName': 'Ana', 'closesAt': 1}),
    ];
    await repository.fetchLastSettled();
    final DrawRepositoryImpl timedOut = DrawRepositoryImpl(
      _NeverCompletingQueryClient(),
      store: DurableJsonStore('draws', directory: directory),
      readTimeout: const Duration(milliseconds: 1),
    );
    expect((await timedOut.fetchLastSettled()).data!.winnerName, 'Ana');
  });
}
