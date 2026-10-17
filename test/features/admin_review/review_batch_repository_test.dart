import 'package:Prism/features/admin_review/data/review_batch_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

FakeDocRow _wall(int i, {bool inDrop = false}) =>
    (id: 'W$i', data: <String, dynamic>{'review': false, if (inDrop) 'dropWeek': '2026-W42'});

void main() {
  test('pages through Drop walls until the batch is full', () async {
    final FakeFirestoreClient client = FakeFirestoreClient();
    client.onQuery = (spec) {
      final int start = spec.startAfterDocId == null ? 0 : int.parse(spec.startAfterDocId!.substring(1)) + 1;
      return <FakeDocRow>[for (int i = start; i < start + 20; i++) _wall(i, inDrop: i < 30)];
    };

    final walls = await ReviewBatchRepository(client).fetchPendingWallsBatch();

    expect(walls.map((w) => w.id), <String>[for (int i = 30; i < 50; i++) 'W$i']);
    expect(client.querySpecs.map((s) => s.startAfterDocId), <String?>[null, 'W19', 'W39']);
    expect(client.querySpecs.every((s) => s.limit == 20), isTrue);
  });

  test('stops when the query runs out', () async {
    final FakeFirestoreClient client = FakeFirestoreClient();
    client.onQuery = (spec) => spec.startAfterDocId == null
        ? <FakeDocRow>[for (int i = 0; i < 20; i++) _wall(i, inDrop: i.isEven)]
        : <FakeDocRow>[_wall(20), _wall(21, inDrop: true)];

    final walls = await ReviewBatchRepository(client).fetchPendingWallsBatch();

    expect(walls, hasLength(11));
    expect(client.querySpecs, hasLength(2));
  });
}
