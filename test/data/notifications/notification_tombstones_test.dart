import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/data/notifications/notification_tombstones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

void main() {
  late InMemoryLocalStore store;
  late NotificationTombstones tombstones;

  setUp(() {
    store = InMemoryLocalStore();
    tombstones = NotificationTombstones(store);
  });

  test('persists deleted ids under the shared key and ignores blanks and repeats', () async {
    await tombstones.addDeleted(<String>['a', '', 'a', 'b']);

    expect(store.get(PersistenceKeys.notificationsDeletedIds), <String>['a', 'b']);
    expect(NotificationTombstones(store).deletedIds(), <String>{'a', 'b'});
  });

  test('keeps only the newest 500 ids', () async {
    await tombstones.addDeleted(List<String>.generate(NotificationTombstones.maxIds, (i) => 'id$i'));
    await tombstones.addDeleted(<String>['newest']);

    final ids = tombstones.deletedIds();
    expect(ids, hasLength(NotificationTombstones.maxIds));
    expect(ids, contains('newest'));
    expect(ids, isNot(contains('id0')));
  });

  test('removeDeleted forgets the given ids', () async {
    await tombstones.addDeleted(<String>['a', 'b']);

    await tombstones.removeDeleted(<String>['a']);

    expect(tombstones.deletedIds(), <String>{'b'});
  });

  test('fetchFloor uses the last clear only when it is later than the backfill start', () async {
    final backfill = DateTime.utc(2026);
    expect(tombstones.fetchFloor(backfill), backfill);

    await tombstones.markCleared(<String>['a'], DateTime.utc(2025, 12));
    expect(tombstones.fetchFloor(backfill), backfill);

    await tombstones.markCleared(<String>['b'], DateTime.utc(2026, 1, 5));
    expect(tombstones.fetchFloor(backfill), DateTime.utc(2026, 1, 5));
    expect(tombstones.deletedIds(), <String>{'a', 'b'});
  });
}
