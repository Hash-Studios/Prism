import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/features/in_app_notifications/data/repositories/notifications_repository_impl.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_user_block_repository.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../in_app_notification_fixture.dart';

void main() {
  group('NotificationsRepositoryImpl', () {
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

      final repo = NotificationsRepositoryImpl(local);
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
      final repo = NotificationsRepositoryImpl(local);

      final result = await repo.markAsRead(id: 'mid');

      expect(result.data!.map((item) => item.id), <String>['new', 'mid', 'old']);
      expect(result.data!.singleWhere((item) => item.id == 'mid').read, isTrue);
    });

    test('rejects a blank notification id', () async {
      final repo = NotificationsRepositoryImpl(_FakeNotificationsLocalDataSource(const <InAppNotificationEntity>[]));

      expect((await repo.markAsRead(id: '  ')).failure, isA<ValidationFailure>());
      expect((await repo.deleteById(id: '')).failure, isA<ValidationFailure>());
    });

    test('deleteByIds trims and dedupes ids and rejects an empty list', () async {
      final local = _FakeNotificationsLocalDataSource(<InAppNotificationEntity>[
        notification('a'),
        notification('b'),
        notification('c'),
      ]);
      final repo = NotificationsRepositoryImpl(local);

      final result = await repo.deleteByIds(ids: <String>[' a ', 'a', 'b', '']);

      expect(result.data!.map((item) => item.id), <String>['c']);
      expect(local.deletedIds, <String>['a', 'b']);
      expect((await repo.deleteByIds(ids: <String>['', '  '])).failure, isA<ValidationFailure>());
    });

    test('clearAll empties the inbox', () async {
      final local = _FakeNotificationsLocalDataSource(<InAppNotificationEntity>[notification('a')]);
      final repo = NotificationsRepositoryImpl(local);

      final result = await repo.clearAll();

      expect(result.data, isEmpty);
      expect(await local.readAll(), isEmpty);
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

  @override
  Future<void> clearAll() async {
    _items = <InAppNotificationEntity>[];
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
