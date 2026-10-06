import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/notifications/notification_tombstones.dart';
import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';
import '../../support/fake_user_block_repository.dart';
import '../../support/in_memory_local_store.dart';

class _MemoryNotificationsLocal extends NotificationsLocalDataSource {
  _MemoryNotificationsLocal() : super(InMemoryLocalStore());

  List<InAppNotificationEntity> items = <InAppNotificationEntity>[];
  DateTime? lastFetch;

  @override
  Future<List<InAppNotificationEntity>> readAll() async => List<InAppNotificationEntity>.from(items);

  @override
  Future<void> writeAll(List<InAppNotificationEntity> value) async => items = List<InAppNotificationEntity>.from(value);

  @override
  Future<void> upsertAll(List<InAppNotificationEntity> incoming) async {
    final byId = <String, InAppNotificationEntity>{for (final item in items) item.id: item};
    for (final item in incoming) {
      byId[item.id] = item;
    }
    items = byId.values.toList(growable: false);
  }

  @override
  Future<void> removeWhere(bool Function(InAppNotificationEntity item) predicate) async {
    items = items.where((item) => !predicate(item)).toList(growable: false);
  }

  @override
  DateTime? lastFetchAtUtc() => lastFetch;

  @override
  Future<void> setLastFetchAtUtc(DateTime value) async => lastFetch = value;
}

Map<String, dynamic> _remoteDoc(String title, DateTime createdAt) => <String, dynamic>{
  'notification': <String, dynamic>{'title': title, 'body': 'body'},
  'data': <String, dynamic>{'pageName': 'wall'},
  'createdAt': createdAt,
};

String _idFor(String title, DateTime createdAt) =>
    buildInAppNotificationId(title: title, body: 'body', pageName: 'wall', url: '', createdAt: createdAt);

void main() {
  late _MemoryNotificationsLocal local;
  late NotificationTombstones tombstones;
  late FakeFirestoreClient client;
  late DateTime recent;
  late DateTime older;

  setUp(() async {
    await getIt.reset();
    clearInAppNotificationSyncGateAll();
    recent = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    older = DateTime.now().toUtc().subtract(const Duration(days: 2));
    local = _MemoryNotificationsLocal();
    tombstones = NotificationTombstones(InMemoryLocalStore());
    client = FakeFirestoreClient(
      onQuery: (FirestoreQuerySpec spec) => <FakeDocRow>[
        (id: 'a', data: _remoteDoc('first', recent)),
        (id: 'b', data: _remoteDoc('second', older)),
      ],
    );
    final blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    getIt
      ..registerSingleton<NotificationsLocalDataSource>(local)
      ..registerSingleton<NotificationTombstones>(tombstones)
      ..registerSingleton<FirestoreClient>(client)
      ..registerSingleton<UserBlockRepository>(blocks);
    app_state.prismUser
      ..loggedIn = true
      ..id = 'user-1'
      ..email = 'user@example.com';
  });

  tearDown(() async {
    app_state.prismUser
      ..loggedIn = false
      ..id = ''
      ..email = '';
    clearInAppNotificationSyncGateAll();
    await getIt.reset();
  });

  test('a forced sync restores everything when nothing was deleted', () async {
    await syncInAppNotificationsFromRemote(force: true);

    expect(local.items.map((item) => item.title), unorderedEquals(<String>['first', 'second']));
  });

  test('a deleted notification stays deleted after a forced sync', () async {
    await tombstones.addDeleted(<String>[_idFor('first', recent)]);

    await syncInAppNotificationsFromRemote(force: true);

    expect(local.items.map((item) => item.title), <String>['second']);
  });

  test('a deleted notification stays deleted after an incremental sync', () async {
    local.lastFetch = DateTime.now().toUtc().subtract(const Duration(days: 3));
    await tombstones.addDeleted(<String>[_idFor('second', older)]);

    await syncInAppNotificationsFromRemote();

    expect(local.items.map((item) => item.title), <String>['first']);
  });

  test('after a clear, a forced sync only asks for notifications newer than the clear', () async {
    final clearedAt = DateTime.now().toUtc().subtract(const Duration(hours: 5));
    await tombstones.markCleared(const <String>[], clearedAt);

    await syncInAppNotificationsFromRemote(force: true);

    expect(local.items.map((item) => item.title), <String>['first']);
    final since =
        client.querySpecs.single.filters.firstWhere((filter) => filter.field == 'createdAt').value! as DateTime;
    expect(since.isAtSameMomentAs(clearedAt), isTrue);
  });

  test('read state survives a forced sync', () async {
    local.items = <InAppNotificationEntity>[
      InAppNotificationEntity(
        id: _idFor('first', recent),
        title: 'first',
        pageName: 'wall',
        body: 'body',
        imageUrl: '',
        arguments: const <Object>[],
        url: '',
        createdAt: recent,
        read: true,
      ),
    ];

    await syncInAppNotificationsFromRemote(force: true);

    expect(local.items.singleWhere((item) => item.title == 'first').read, isTrue);
  });
}
