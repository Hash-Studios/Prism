import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/data/notifications/notification_tombstones.dart';
import 'package:Prism/features/in_app_notifications/data/repositories/notifications_repository_impl.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_user_block_repository.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../in_app_notification_fixture.dart';

void main() {
  group('NotificationsRepositoryImpl', () {
    late NotificationTombstones tombstones;

    setUp(() {
      tombstones = NotificationTombstones(InMemoryLocalStore());
    });

    tearDown(() async {
      await getIt.reset();
    });

    test('waits for blocked creators and prunes cached blocked notifications before returning local data', () async {
      final blocks = FakeUserBlockRepository.pending();
      final local = _FakeNotificationsLocalDataSource(<InAppNotificationEntity>[
        notification('blocked', followerEmail: 'blocked@example.com'),
        notification('visible', followerEmail: 'visible@example.com'),
      ]);
      getIt.registerSingleton<UserBlockRepository>(blocks);

      final repo = NotificationsRepositoryImpl(local, tombstones);
      final pending = repo.fetchNotifications(syncRemote: false);

      await Future<void>.delayed(Duration.zero);
      expect(local.readCount, 0);

      blocks.completeInitial(<String>{'blocked@example.com'});

      final result = await pending;
      expect(result.isSuccess, isTrue);
      expect(result.data!.map((item) => item.id).toList(growable: false), <String>['visible']);
      expect((await local.readAll()).map((item) => item.id).toList(growable: false), <String>['visible']);
    });

    test('lists newest first after every change', () async {
      final local = _FakeNotificationsLocalDataSource(<InAppNotificationEntity>[
        notification('old', createdAt: DateTime.utc(2024)),
        notification('new', createdAt: DateTime.utc(2025)),
        notification('mid', createdAt: DateTime.utc(2024, 6)),
      ]);
      final repo = NotificationsRepositoryImpl(local, tombstones);

      final result = await repo.markAsRead(id: 'mid');

      expect(result.data!.map((item) => item.id), <String>['new', 'mid', 'old']);
      expect(result.data!.singleWhere((item) => item.id == 'mid').read, isTrue);
    });

    test('rejects a blank notification id', () async {
      final repo = NotificationsRepositoryImpl(
        _FakeNotificationsLocalDataSource(const <InAppNotificationEntity>[]),
        tombstones,
      );

      expect((await repo.markAsRead(id: '  ')).failure, isA<ValidationFailure>());
      expect((await repo.deleteById(id: '')).failure, isA<ValidationFailure>());
    });

    test('deleteByIds trims and dedupes ids and rejects an empty list', () async {
      final local = _FakeNotificationsLocalDataSource(<InAppNotificationEntity>[
        notification('a'),
        notification('b'),
        notification('c'),
      ]);
      final repo = NotificationsRepositoryImpl(local, tombstones);

      final result = await repo.deleteByIds(ids: <String>[' a ', 'a', 'b', '']);

      expect(result.data!.map((item) => item.id), <String>['c']);
      expect(local.deletedIds, <String>['a', 'b']);
      expect((await repo.deleteByIds(ids: <String>['', '  '])).failure, isA<ValidationFailure>());
    });

    test('clearAll empties the inbox', () async {
      final local = _FakeNotificationsLocalDataSource(<InAppNotificationEntity>[notification('a')]);
      final repo = NotificationsRepositoryImpl(local, tombstones);

      final result = await repo.clearAll();

      expect(result.data, isEmpty);
      expect(await local.readAll(), isEmpty);
    });

    test('delete and deleteByIds remember the removed ids', () async {
      final local = _FakeNotificationsLocalDataSource(<InAppNotificationEntity>[
        notification('a'),
        notification('b'),
        notification('c'),
      ]);
      final repo = NotificationsRepositoryImpl(local, tombstones);

      await repo.deleteById(id: 'a');
      await repo.deleteByIds(ids: <String>['b']);

      expect(tombstones.deletedIds(), <String>{'a', 'b'});
    });

    test('clearAll remembers every id and moves the fetch watermark to now instead of resetting it', () async {
      final local = _FakeNotificationsLocalDataSource(<InAppNotificationEntity>[notification('a'), notification('b')]);
      final repo = NotificationsRepositoryImpl(local, tombstones);
      final before = DateTime.now().toUtc();

      await repo.clearAll();

      expect(tombstones.deletedIds(), <String>{'a', 'b'});
      expect(tombstones.clearedAtUtc()!.isBefore(before), isFalse);
      expect(local.lastFetch, isNotNull);
      expect(local.lastFetch!.isBefore(before), isFalse);
    });

    test('markAllAsRead marks every unread notification read', () async {
      final local = _FakeNotificationsLocalDataSource(<InAppNotificationEntity>[
        notification('a'),
        notification('b', read: true),
        notification('c'),
      ]);
      final repo = NotificationsRepositoryImpl(local, tombstones);

      final result = await repo.markAllAsRead();

      expect(result.data!.every((item) => item.read), isTrue);
      expect(result.data, hasLength(3));
    });

    test('restore brings removed notifications back and forgets their tombstones', () async {
      final removed = notification('a', read: true);
      final local = _FakeNotificationsLocalDataSource(<InAppNotificationEntity>[notification('b')]);
      final repo = NotificationsRepositoryImpl(local, tombstones);
      await tombstones.addDeleted(<String>['a', 'x']);

      final result = await repo.restore(items: <InAppNotificationEntity>[removed]);

      expect(result.data!.map((item) => item.id), containsAll(<String>['a', 'b']));
      expect(result.data!.singleWhere((item) => item.id == 'a').read, isTrue);
      expect(tombstones.deletedIds(), <String>{'x'});
      expect((await repo.restore(items: const <InAppNotificationEntity>[])).failure, isA<ValidationFailure>());
    });
  });
}

class _FakeNotificationsLocalDataSource extends NotificationsLocalDataSource {
  _FakeNotificationsLocalDataSource(List<InAppNotificationEntity> items)
    : _items = List<InAppNotificationEntity>.from(items),
      super(InMemoryLocalStore());

  List<InAppNotificationEntity> _items;
  int readCount = 0;
  List<String> deletedIds = <String>[];
  DateTime? lastFetch;

  @override
  Future<void> clearAll() async {
    _items = <InAppNotificationEntity>[];
  }

  @override
  Future<void> setLastFetchAtUtc(DateTime value) async {
    lastFetch = value;
  }

  @override
  Future<void> writeAll(List<InAppNotificationEntity> items) async {
    _items = List<InAppNotificationEntity>.from(items);
  }

  @override
  Future<void> upsertAll(List<InAppNotificationEntity> incoming) async {
    final byId = <String, InAppNotificationEntity>{for (final item in _items) item.id: item};
    for (final item in incoming) {
      byId[item.id] = item;
    }
    _items = byId.values.toList(growable: false);
  }

  @override
  Future<void> deleteById(String id) async {
    _items = _items.where((item) => item.id != id).toList(growable: false);
  }

  @override
  Future<void> deleteByIds(List<String> ids) async {
    deletedIds = ids;
    _items = _items.where((item) => !ids.contains(item.id)).toList(growable: false);
  }

  @override
  Future<void> markAsRead(String id) async {
    _items = _items.map((item) => item.id == id ? item.copyWith(read: true) : item).toList(growable: false);
  }

  @override
  Future<List<InAppNotificationEntity>> readAll() async {
    readCount += 1;
    return List<InAppNotificationEntity>.from(_items);
  }

  @override
  Future<void> removeWhere(bool Function(InAppNotificationEntity item) predicate) async {
    _items = _items.where((item) => !predicate(item)).toList(growable: false);
  }
}
