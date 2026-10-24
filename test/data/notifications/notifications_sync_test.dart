import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/notifications/notification_tombstones.dart';
import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/features/in_app_notifications/data/repositories/notifications_repository_impl.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';
import '../../support/fake_user_block_repository.dart';

class _MemoryNotificationsLocal extends NotificationsLocalDataSource {
  _MemoryNotificationsLocal() : super();

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
  Future<void> clearAll() async => items = <InAppNotificationEntity>[];

  @override
  Future<DateTime?> lastFetchAtUtc() async => lastFetch;

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
  late Directory directory;

  setUp(() async {
    await getIt.reset();
    clearInAppNotificationSyncGateAll();
    recent = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    older = DateTime.now().toUtc().subtract(const Duration(days: 2));
    local = _MemoryNotificationsLocal();
    directory = Directory.systemTemp.createTempSync('notifications_sync_test');
    tombstones = NotificationTombstones.withStore(DurableJsonStore('notifications_sync_test', directory: directory));
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
    directory.deleteSync(recursive: true);
  });

  test('a forced sync restores everything when nothing was deleted', () async {
    await syncInAppNotificationsFromRemote(force: true);

    expect(local.items.map((item) => item.title), unorderedEquals(<String>['first', 'second']));
    expect(client.querySpecs.single.cachePolicy, FirestoreCachePolicy.networkOnly);
    expect(client.querySpecs.single.dedupeWindowMs, 0);
  });

  test('a sync started for account A is discarded after switching to account B', () async {
    final blocks = FakeUserBlockRepository.pending();
    await getIt.unregister<UserBlockRepository>();
    getIt.registerSingleton<UserBlockRepository>(blocks);

    final pending = syncInAppNotificationsFromRemote(force: true);
    await Future<void>.delayed(Duration.zero);
    app_state.prismUser
      ..loggedIn = true
      ..id = 'user-2'
      ..email = 'other@example.com';
    clearInAppNotificationSyncGateAll();
    blocks.completeInitial(<String>{});

    await pending;

    expect(client.querySpecs, isEmpty);
    expect(local.items, isEmpty);
  });

  test('a signed-in session without an ID uses the guest stores and does not fall back to email', () async {
    local.setOwner('previous-account');
    tombstones.setOwner('previous-account');
    app_state.prismUser
      ..loggedIn = true
      ..id = '  '
      ..email = 'user@example.com';

    await syncInAppNotificationsFromRemote(force: true);

    expect(local.ownerId, 'guest');
    expect(tombstones.ownerId, 'guest');
    expect(client.querySpecs, isEmpty);
  });

  test('a deleted notification stays deleted after a forced sync', () async {
    tombstones.setOwner('user-1');
    await tombstones.addDeleted(<String>[_idFor('first', recent)]);

    await syncInAppNotificationsFromRemote(force: true);

    expect(tombstones.ownerId, 'user-1');
    expect(local.items.map((item) => item.title), <String>['second']);
  });

  test('a deleted notification stays deleted after an incremental sync', () async {
    tombstones.setOwner('user-1');
    local.lastFetch = DateTime.now().toUtc().subtract(const Duration(days: 3));
    await tombstones.addDeleted(<String>[_idFor('second', older)]);

    await syncInAppNotificationsFromRemote();

    expect(tombstones.ownerId, 'user-1');
    expect(local.items.map((item) => item.title), <String>['first']);
    expect(client.querySpecs.single.cachePolicy, FirestoreCachePolicy.networkOnly);
    expect(client.querySpecs.single.dedupeWindowMs, 0);
  });

  test('after a clear, a forced sync only asks for notifications newer than the clear', () async {
    tombstones.setOwner('user-1');
    final clearedAt = DateTime.now().toUtc().subtract(const Duration(hours: 5));
    await tombstones.markCleared(const <String>[], clearedAt);

    await syncInAppNotificationsFromRemote(force: true);

    expect(tombstones.ownerId, 'user-1');
    expect(local.items.map((item) => item.title), <String>['first']);
    final since =
        client.querySpecs.single.filters.firstWhere((filter) => filter.field == 'createdAt').value! as DateTime;
    expect(since.isAtSameMomentAs(clearedAt), isTrue);
  });

  test('Undo after Clear inbox keeps the notifications through the next forced sync', () async {
    final repo = NotificationsRepositoryImpl(local, tombstones);
    await syncInAppNotificationsFromRemote(force: true);
    final cleared = List<InAppNotificationEntity>.from(local.items);

    await repo.clearAll();
    await repo.restore(items: cleared);
    clearInAppNotificationSyncGateAll();
    await syncInAppNotificationsFromRemote(force: true);

    expect(local.items.map((item) => item.title), unorderedEquals(<String>['first', 'second']));
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

  test('a startup sync skips the fetch when the last fetch was under 5 minutes ago', () async {
    local.lastFetch = DateTime.now().toUtc().subtract(const Duration(minutes: 2));

    await syncInAppNotificationsFromRemote();

    expect(client.querySpecs, isEmpty);
  });

  test('a startup sync still prunes blocked actors while its fetch is cooling down', () async {
    local.lastFetch = DateTime.now().toUtc().subtract(const Duration(minutes: 2));
    local.items = <InAppNotificationEntity>[
      InAppNotificationEntity(
        id: 'blocked',
        title: 'blocked actor',
        pageName: 'profile',
        body: 'body',
        imageUrl: '',
        arguments: const <Object>[],
        url: '',
        createdAt: recent,
        read: false,
        followerUid: 'blocked_uid',
      ),
    ];
    final FakeUserBlockRepository blocks = getIt<UserBlockRepository>() as FakeUserBlockRepository
      ..completeInitial(<String>{'blocked_uid'});
    blocks.blockedRows = const <BlockedUserListRow>[BlockedUserListRow(blockedUid: 'blocked_uid')];

    await syncInAppNotificationsFromRemote();

    expect(client.querySpecs, isEmpty);
    expect(local.items, isEmpty);
  });

  test('a future persisted fetch time does not suppress synchronization', () async {
    final DateTime now = DateTime.now().toUtc();
    local.lastFetch = now.add(const Duration(days: 1));

    await syncInAppNotificationsFromRemote();

    final Object? since = client.querySpecs.single.filters.firstWhere((filter) => filter.field == 'createdAt').value;
    expect(since, isA<DateTime>());
    expect((since! as DateTime).isBefore(now), isTrue);
    expect(local.lastFetch!.isBefore(now.add(const Duration(seconds: 1))), isTrue);
  });

  test('a startup sync fetches only newer notifications when the last fetch was over 5 minutes ago', () async {
    final DateTime lastFetch = DateTime.now().toUtc().subtract(const Duration(minutes: 10));
    local.lastFetch = lastFetch;

    await syncInAppNotificationsFromRemote();

    expect(client.querySpecs.single.sourceTag, 'notifications.latest');
  });

  test('a forced sync fetches even when the last fetch was under 5 minutes ago', () async {
    local.lastFetch = DateTime.now().toUtc().subtract(const Duration(minutes: 2));

    await syncInAppNotificationsFromRemote(force: true);

    expect(client.querySpecs, hasLength(1));
  });
}
