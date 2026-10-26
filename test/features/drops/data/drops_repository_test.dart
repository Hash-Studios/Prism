import 'dart:io';

import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/drops/data/repositories/drops_repository_impl.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/coins_test_backend.dart';
import '../../../support/fake_firestore_client.dart';

class _NeverQueryClient extends FakeFirestoreClient {
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

Map<String, dynamic> _doc({required int startsAt, required int endsAt}) => <String, dynamic>{
  'title': 'Autumn',
  'startsAt': startsAt,
  'endsAt': endsAt,
  'priceWall': 30,
  'pricePack': 150,
  'count': 2,
  'walls': <Map<String, Object?>>[
    <String, Object?>{'id': 'A', 'title': 'One', 'thumb': 't1', 'resolution': '1x1', 'by': 'Ana', 'seriesId': 's'},
    <String, Object?>{'id': '', 'title': 'No id'},
    <String, Object?>{'id': 'B', 'title': 'Two', 'thumb': 't2'},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final DateTime now = DateTime.utc(2026, 10, 14, 12);
  final int ms = now.millisecondsSinceEpoch;
  late FakeFirestoreClient client;
  late DropsRepositoryImpl repository;
  late Directory directory;

  setUp(() {
    client = _MetadataFirestoreClient();
    directory = Directory.systemTemp.createTempSync('prism-drops-test');
    repository = DropsRepositoryImpl(client, store: DurableJsonStore('drops', directory: directory));
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('rename updates the offline Drop snapshot used after a transient read failure', () async {
    final CoinsTestBackend backend = CoinsTestBackend();
    await backend.install();
    backend.onCall = (_, _) async => <String, Object?>{'title': 'Night Swim', 'applied': 'drop'};
    client.docs[FirebaseCollections.drops] = {
      '2026-W42': _doc(startsAt: ms - 1000, endsAt: ms + 5000),
    };
    expect((await repository.fetchByWeekKey('2026-W42')).data!.title, 'Autumn');

    final Result<String> renamed = await repository.rename('2026-W42', '  Night   Swim  ');
    expect(renamed.data, 'Night Swim');

    repository = DropsRepositoryImpl(client, store: DurableJsonStore('drops', directory: directory));
    client.queryError = FirestoreError(code: 'unavailable', message: 'offline');
    final Result<DropEntity?> offline = await repository.fetchByWeekKey('2026-W42');

    expect(offline.data!.title, 'Night Swim');
  });

  group('fetchLive', () {
    test('asks for the next Drop that has not ended, oldest end first', () async {
      await repository.fetchLive(now);

      final FirestoreQuerySpec spec = client.querySpecs.single;
      expect(spec.collection, FirebaseCollections.drops);
      expect(spec.sourceTag, 'drops.live');
      expect(spec.filters.single.field, 'endsAt');
      expect(spec.filters.single.op, FirestoreFilterOp.isGreaterThan);
      expect(spec.filters.single.value, ms);
      expect(spec.orderBy.single.field, 'endsAt');
      expect(spec.orderBy.single.descending, isFalse);
      expect(spec.limit, 1);
    });

    test('maps the doc, skips walls without an id and reads epoch ms times', () async {
      client.onQuery = (_) => [(id: '2026-W42', data: _doc(startsAt: ms - 1000, endsAt: ms + 1000))];

      final drop = (await repository.fetchLive(now)).data!;

      expect(drop.weekKey, '2026-W42');
      expect(drop.title, 'Autumn');
      expect(drop.startsAt, DateTime.fromMillisecondsSinceEpoch(ms - 1000, isUtc: true));
      expect((drop.priceWall, drop.pricePack, drop.count), (30, 150, 2));
      expect(drop.walls.map((w) => w.id), <String>['A', 'B']);
      expect(drop.walls.first.by, 'Ana');
    });

    test('is null when the next Drop has not started yet', () async {
      client.onQuery = (_) => [(id: '2026-W43', data: _doc(startsAt: ms + 1000, endsAt: ms + 5000))];

      expect((await repository.fetchLive(now)).data, isNull);
    });

    test('is null when there is no Drop, and a failure when the query throws', () async {
      expect((await repository.fetchLive(now)).data, isNull);

      client.queryError = StateError('boom');
      expect((await repository.fetchLive(now)).isFailure, isTrue);
    });

    test('skips a doc with no time window', () async {
      client.onQuery = (_) => [
        (id: '2026-W42', data: <String, dynamic>{'title': 'Broken'}),
      ];

      expect((await repository.fetchLive(now)).data, isNull);
    });
  });

  group('fetchByWeekKey', () {
    test('reads the doc by id', () async {
      client.docs[FirebaseCollections.drops] = {'2026-W41': _doc(startsAt: ms - 9000, endsAt: ms - 1000)};

      expect((await repository.fetchByWeekKey('2026-W41')).data!.weekKey, '2026-W41');
      expect((await repository.fetchByWeekKey('2026-W01')).data, isNull);
    });
  });

  test('persists recent weeks across repository restart for transient failures only', () async {
    client.onQuery = (_) => [(id: '2026-W42', data: _doc(startsAt: ms - 1000, endsAt: ms + 5000))];
    expect((await repository.fetchLive(now)).data!.title, 'Autumn');

    final FakeFirestoreClient offline = _MetadataFirestoreClient()
      ..queryError = FirestoreError(code: 'unavailable', message: 'offline');
    final DropsRepositoryImpl restarted = DropsRepositoryImpl(
      offline,
      store: DurableJsonStore('drops', directory: directory),
      readTimeout: const Duration(milliseconds: 10),
    );
    expect((await restarted.fetchLive(now)).data!.weekKey, '2026-W42');

    final FakeFirestoreClient empty = _MetadataFirestoreClient();
    final DropsRepositoryImpl authoritative = DropsRepositoryImpl(
      empty,
      store: DurableJsonStore('drops', directory: directory),
    );
    expect((await authoritative.fetchLive(now)).data, isNull);
    empty.queryError = FirestoreError(code: 'unavailable', message: 'offline');
    expect((await authoritative.fetchLive(now)).isFailure, isTrue);
  });

  test('skips malformed saved Drops and persists a successful server result', () async {
    final DurableJsonStore store = DurableJsonStore('drops', directory: directory);
    await store.write('recent', <String, Object?>{
      'drops': <Object?>[
        <String, Object?>{'weekKey': 'broken'},
      ],
    });
    client.onQuery = (_) => [(id: '2026-W42', data: _doc(startsAt: ms - 1000, endsAt: ms + 5000))];

    expect((await repository.fetchLive(now)).data!.weekKey, '2026-W42');

    final FakeFirestoreClient offline = _MetadataFirestoreClient()
      ..queryError = FirestoreError(code: 'unavailable', message: 'offline');
    final DropsRepositoryImpl restarted = DropsRepositoryImpl(offline, store: store);
    expect((await restarted.fetchLive(now)).data!.weekKey, '2026-W42');
  });

  test('bounded repository timeout falls back to the recent saved Drop', () async {
    client.onQuery = (_) => [(id: '2026-W42', data: _doc(startsAt: ms - 1000, endsAt: ms + 5000))];
    await repository.fetchLive(now);
    final DropsRepositoryImpl timedOut = DropsRepositoryImpl(
      _NeverQueryClient(),
      store: DurableJsonStore('drops', directory: directory),
      readTimeout: const Duration(milliseconds: 1),
    );
    expect((await timedOut.fetchLive(now)).data!.weekKey, '2026-W42');
  });
}
