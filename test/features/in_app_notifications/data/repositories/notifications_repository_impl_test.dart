
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/features/in_app_notifications/data/repositories/notifications_repository_impl.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_user_block_repository.dart';
import '../../../../support/in_memory_local_store.dart';

void main() {
  group('NotificationsRepositoryImpl', () {
    tearDown(() async {
      await getIt.reset();
    });

    test('waits for blocked creators and prunes cached blocked notifications before returning local data', () async {
      final blocks = FakeUserBlockRepository.pending();
      final local = _FakeNotificationsLocalDataSource(<InAppNotificationEntity>[
        _notification(id: 'blocked', followerEmail: 'blocked@example.com'),
        _notification(id: 'visible', followerEmail: 'visible@example.com'),
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
  });
}

class _FakeNotificationsLocalDataSource extends NotificationsLocalDataSource {
  _FakeNotificationsLocalDataSource(List<InAppNotificationEntity> items)
    : _items = List<InAppNotificationEntity>.from(items),
      super(InMemoryLocalStore());

  List<InAppNotificationEntity> _items;
  int readCount = 0;

  @override
  Future<void> clearAll() async {
    _items = <InAppNotificationEntity>[];
  }

  @override
  Future<void> deleteById(String id) async {
    _items = _items.where((item) => item.id != id).toList(growable: false);
  }

  @override
  DateTime? lastFetchAtUtc() => null;

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

  @override
  Future<void> setLastFetchAtUtc(DateTime value) async {}

  @override
  Future<void> upsertAll(List<InAppNotificationEntity> incoming) async {
    final Map<String, InAppNotificationEntity> merged = <String, InAppNotificationEntity>{
      for (final item in _items) item.id: item,
      for (final item in incoming) item.id: item,
    };
    _items = merged.values.toList(growable: false);
  }

  @override
  Future<void> writeAll(List<InAppNotificationEntity> items) async {
    _items = List<InAppNotificationEntity>.from(items);
  }
}

InAppNotificationEntity _notification({required String id, required String followerEmail}) {
  return InAppNotificationEntity(
    id: id,
    title: 'Title $id',
    pageName: '/notification',
    body: 'Body $id',
    imageUrl: '',
    arguments: const <Object>[],
    url: '',
    createdAt: DateTime.utc(2026),
    read: false,
    followerEmail: followerEmail,
  );
}
