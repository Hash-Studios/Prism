import 'dart:async';
import 'dart:io';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/data/notifications/notification_tombstones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('notification_tombstones_test');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('persists deleted ids, ignores blanks and repeats, and caps the list', () async {
    final store = DurableJsonStore('notification_tombstones_test', directory: directory);
    final tombstones = NotificationTombstones.withStore(store)..setOwner('account-a');
    await tombstones.addDeleted(<String>['a', '', 'a', 'b']);

    expect(await NotificationTombstones.withStore(store).deletedIds(), isEmpty);
    final reopened = NotificationTombstones.withStore(store)..setOwner('account-a');
    expect(await reopened.deletedIds(), <String>{'a', 'b'});

    await reopened.addDeleted(List<String>.generate(NotificationTombstones.maxIds, (i) => 'id$i'));
    await reopened.addDeleted(<String>['newest']);
    final ids = await reopened.deletedIds();
    expect(ids, hasLength(NotificationTombstones.maxIds));
    expect(ids, contains('newest'));
    expect(ids, isNot(contains('id0')));
  });

  test('deleted ids and clear watermark are isolated by owner', () async {
    final tombstones = NotificationTombstones.withStore(
      DurableJsonStore('notification_tombstone_owners', directory: directory),
    )..setOwner('account-a');
    await tombstones.markCleared(<String>['same-id'], DateTime.utc(2026, 1, 5));

    tombstones.setOwner('account-b');
    expect(await tombstones.deletedIds(), isEmpty);
    expect(await tombstones.clearedAtUtc(), isNull);

    tombstones.setOwner('account-a');
    expect(await tombstones.deletedIds(), <String>{'same-id'});
    expect(await tombstones.clearedAtUtc(), DateTime.utc(2026, 1, 5));
  });

  test('a tombstone write started for one owner is discarded after an owner-generation change', () async {
    final store = _DelayedReadStore('notification_tombstone_generation', directory: directory);
    final tombstones = NotificationTombstones.withStore(store)..setOwner('account-a');
    final pending = tombstones.addDeleted(<String>['private-a']);
    await Future<void>.delayed(Duration.zero);

    tombstones.setOwner('account-b');
    store.completeRead();
    await pending;

    expect(await store.readAll(), isEmpty);
    tombstones.setOwner('account-a');
    expect(await tombstones.deletedIds(), isEmpty);
  });

  test('removeDeleted forgets the given ids and clearForUser deletes only that owner record', () async {
    final tombstones = NotificationTombstones.withStore(
      DurableJsonStore('notification_tombstone_delete', directory: directory),
    )..setOwner('account-a');
    await tombstones.addDeleted(<String>['a', 'b']);
    await tombstones.removeDeleted(<String>['a']);
    expect(await tombstones.deletedIds(), <String>{'b'});
    await tombstones.clearForUser('account-a');
    expect(await tombstones.deletedIds(), isEmpty);
  });

  test('fetchFloor respects the last clear watermark', () async {
    final tombstones = NotificationTombstones.withStore(
      DurableJsonStore('notification_tombstone_floor', directory: directory),
    )..setOwner('account-a');
    final backfill = DateTime.utc(2026);
    expect(await tombstones.fetchFloor(backfill), backfill);

    await tombstones.markCleared(<String>['a'], DateTime.utc(2025, 12));
    expect(await tombstones.fetchFloor(backfill), backfill);

    await tombstones.markCleared(<String>['b'], DateTime.utc(2026, 1, 5));
    expect(await tombstones.fetchFloor(backfill), DateTime.utc(2026, 1, 5));
    expect(await tombstones.deletedIds(), <String>{'a', 'b'});
  });

  test('a durable write failure is surfaced to the caller', () async {
    final blockerPath = File('${directory.path}/not-a-directory')..writeAsStringSync('block');
    final tombstones = NotificationTombstones.withStore(
      DurableJsonStore('notification_tombstone_failure', directory: Directory(blockerPath.path)),
    )..setOwner('account-a');

    await expectLater(tombstones.addDeleted(<String>['id']), throwsA(isA<FileSystemException>()));
  });
}

class _DelayedReadStore extends DurableJsonStore {
  _DelayedReadStore(super.name, {required super.directory});

  final Completer<void> _readGate = Completer<void>();

  void completeRead() => _readGate.complete();

  @override
  Future<Map<String, Object?>?> read(String key) async {
    await _readGate.future;
    return super.read(key);
  }
}
