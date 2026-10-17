import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/drops/data/repositories/drops_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';

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
  final DateTime now = DateTime.utc(2026, 10, 14, 12);
  final int ms = now.millisecondsSinceEpoch;
  late FakeFirestoreClient client;
  late DropsRepositoryImpl repository;

  setUp(() {
    client = FakeFirestoreClient();
    repository = DropsRepositoryImpl(client);
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

  group('fetchPast', () {
    test('asks for ended Drops, newest first, with a limit', () async {
      client.onQuery = (_) => [
        (id: '2026-W41', data: _doc(startsAt: ms - 9000, endsAt: ms - 1000)),
        (id: '2026-W40', data: _doc(startsAt: ms - 19000, endsAt: ms - 11000)),
      ];

      final drops = (await repository.fetchPast(now, limit: 5)).data!;

      final FirestoreQuerySpec spec = client.querySpecs.single;
      expect(spec.sourceTag, 'drops.past');
      expect(spec.filters.single.op, FirestoreFilterOp.isLessThanOrEqualTo);
      expect(spec.filters.single.value, ms);
      expect(spec.orderBy.single.descending, isTrue);
      expect(spec.limit, 5);
      expect(drops.map((d) => d.weekKey), <String>['2026-W41', '2026-W40']);
    });

    test('is a failure when the query throws', () async {
      client.queryError = StateError('boom');

      expect((await repository.fetchPast(now)).isFailure, isTrue);
    });
  });

  group('fetchByWeekKey', () {
    test('reads the doc by id', () async {
      client.docs[FirebaseCollections.drops] = {'2026-W41': _doc(startsAt: ms - 9000, endsAt: ms - 1000)};

      expect((await repository.fetchByWeekKey('2026-W41')).data!.weekKey, '2026-W41');
      expect((await repository.fetchByWeekKey('2026-W01')).data, isNull);
    });
  });
}
