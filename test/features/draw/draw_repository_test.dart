import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/draw/data/repositories/draw_repository_impl.dart';
import 'package:Prism/features/draw/domain/entities/draw_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

void main() {
  late FakeFirestoreClient firestore;
  late DrawRepositoryImpl repository;

  setUp(() {
    firestore = FakeFirestoreClient();
    repository = DrawRepositoryImpl(firestore);
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
    firestore.docs['drawTickets'] = <String, Map<String, dynamic>>{
      '2026-W42_u1': <String, dynamic>{'count': 3},
    };
    expect((await repository.fetchMyTickets('2026-W42', 'u1')).data, 3);
  });

  test('a read error becomes a failure', () async {
    firestore.queryError = StateError('boom');
    expect((await repository.fetchLastSettled()).isFailure, isTrue);
  });
}
