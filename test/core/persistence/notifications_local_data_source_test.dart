import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('notifications_local_test');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  InAppNotificationEntity notification(String id, DateTime createdAt, {String body = '', bool read = false}) =>
      InAppNotificationEntity(
        id: id,
        title: id,
        pageName: 'wall',
        body: body,
        imageUrl: '',
        arguments: const <Object>[],
        url: '',
        createdAt: createdAt,
        read: read,
      );

  test('every structured kind survives a durable reopen without English copy heuristics', () async {
    final store = DurableJsonStore('notification_kinds', directory: directory);
    final local = NotificationsLocalDataSource.withStore(store)..setOwner('account-a');
    await local.writeAll(<InAppNotificationEntity>[
      for (final kind in InAppNotificationKind.values)
        notification(kind.name, DateTime.utc(2026), body: '通知').copyWith(title: 'お知らせ', kind: kind),
    ]);

    final reopened = NotificationsLocalDataSource.withStore(
      DurableJsonStore('notification_kinds', directory: directory),
    )..setOwner('account-a');
    expect(
      <String, InAppNotificationKind?>{for (final item in await reopened.readAll()) item.id: item.kind},
      <String, InAppNotificationKind>{for (final kind in InAppNotificationKind.values) kind.name: kind},
    );
  });

  test('legacy missing and unknown kind values decode without inventing a kind', () async {
    final store = DurableJsonStore('notification_legacy_kinds', directory: directory);
    await store.write('owner:${base64Url.encode(utf8.encode('account-a'))}', <String, Object?>{
      'items': <Map<String, Object?>>[
        <String, Object?>{'id': 'missing'},
        <String, Object?>{'id': 'unknown', 'kind': 'futureKind'},
        <String, Object?>{'id': 'old-index', 'kind': 1},
        <String, Object?>{'id': 'known', 'kind': 'wallApproved'},
      ],
    });
    final local = NotificationsLocalDataSource.withStore(store)..setOwner('account-a');

    expect(
      <String, InAppNotificationKind?>{for (final item in await local.readAll()) item.id: item.kind},
      <String, InAppNotificationKind?>{
        'missing': null,
        'unknown': null,
        'old-index': null,
        'known': InAppNotificationKind.wallApproved,
      },
    );
  });

  test('notification records and fetch watermark remain isolated by account', () async {
    final store = DurableJsonStore('notifications-test', directory: directory);
    final local = NotificationsLocalDataSource.withStore(store)..setOwner('account-a');
    final notification = InAppNotificationEntity(
      id: 'account-a-notification',
      title: 'A',
      pageName: 'wall',
      body: '',
      imageUrl: '',
      arguments: const <Object>[],
      url: '',
      createdAt: DateTime.utc(2026),
      read: false,
    );
    await local.writeAll(<InAppNotificationEntity>[notification]);
    await local.setLastFetchAtUtc(DateTime.utc(2026));

    local.setOwner('account-b');
    expect(await local.readAll(), isEmpty);
    expect(await local.lastFetchAtUtc(), isNull);

    local.setOwner('account-a');
    expect((await local.readAll()).single.id, notification.id);
    expect(await local.lastFetchAtUtc(), DateTime.utc(2026));

    final afterRestart = NotificationsLocalDataSource.withStore(store)..setOwner('account-a');
    expect((await afterRestart.readAll()).single.id, notification.id);
  });

  test('inbox mutations preserve read state and clearAll resets items and the fetch watermark', () async {
    final NotificationsLocalDataSource local = NotificationsLocalDataSource.withStore(
      DurableJsonStore('notifications_mutations', directory: directory),
    )..setOwner('account-a');
    final DateTime now = DateTime.utc(2026, 10, 20);
    await local.upsertAll(<InAppNotificationEntity>[
      notification('first', now),
      notification('second', now.add(const Duration(minutes: 1))),
    ]);
    await local.markAsRead('first');
    await local.upsertAll(<InAppNotificationEntity>[notification('first', now, body: 'updated')]);
    expect((await local.readAll()).last.read, isTrue);
    expect((await local.readAll()).last.body, 'updated');

    await local.deleteByIds(<String>[]);
    await local.deleteByIds(<String>['second', 'missing']);
    await local.setLastFetchAtUtc(DateTime.utc(2026, 10, 21));
    expect(await local.lastFetchAtUtc(), DateTime.utc(2026, 10, 21));
    expect((await local.readAll()).map((item) => item.id), <String>['first']);

    await local.removeWhere((item) => item.id == 'first');
    await local.setLastFetchAtUtc(DateTime.utc(2026, 10, 22));
    await local.clearAll();
    expect(await local.readAll(), isEmpty);
    expect(await local.lastFetchAtUtc(), isNull);
  });

  test('clearForUser removes only the selected owner record', () async {
    final store = DurableJsonStore('notifications_clear_user', directory: directory);
    final local = NotificationsLocalDataSource.withStore(store)..setOwner('account-a');
    final item = InAppNotificationEntity(
      id: 'private',
      title: 'Private',
      pageName: 'wall',
      body: '',
      imageUrl: '',
      arguments: const <Object>[],
      url: '',
      createdAt: DateTime.utc(2026),
      read: false,
    );
    await local.writeAll(<InAppNotificationEntity>[item]);
    local.setOwner('account-b');
    await local.writeAll(<InAppNotificationEntity>[item.copyWith(id: 'other')]);

    await local.clearForUser('account-a');
    local.setOwner('account-a');
    expect(await local.readAll(), isEmpty);
    local.setOwner('account-b');
    expect((await local.readAll()).single.id, 'other');
  });

  test('structured notification copy survives a local cache round trip', () async {
    final DurableJsonStore store = DurableJsonStore('notifications_copy', directory: directory);
    final NotificationsLocalDataSource local = NotificationsLocalDataSource.withStore(store)..setOwner('account-a');
    final InAppNotificationEntity item = InAppNotificationEntity(
      id: 'localized-notification',
      title: 'A new Drop is live',
      pageName: 'drop',
      body: '2 walls, this week only.',
      imageUrl: '',
      arguments: const <Object>[],
      url: '',
      createdAt: DateTime.utc(2026, 10, 19),
      read: false,
      copyKind: 'dropLive',
      copyArgs: const <String, Object?>{
        'wallCount': 2,
        'metadata': <String, Object?>{'source': 'weekly'},
      },
    );

    await local.writeAll(<InAppNotificationEntity>[item]);

    final NotificationsLocalDataSource afterRestart = NotificationsLocalDataSource.withStore(store)
      ..setOwner('account-a');
    final InAppNotificationEntity restored = (await afterRestart.readAll()).single;
    expect(restored.copyKind, 'dropLive');
    expect(restored.copyArgs, item.copyArgs);
  });

  test(
    'upsert retains newest notifications within the encoded byte cap and preserves read state and fetch cursor',
    () async {
      final Directory storeDirectory = Directory('${directory.path}/byte_cap')..createSync();
      final store = DurableJsonStore('notifications_byte_cap', directory: storeDirectory);
      final local = NotificationsLocalDataSource.withStore(store)..setOwner('account-a');
      final DateTime fetchedAt = DateTime.utc(2026, 10, 17);
      final String body = List<String>.filled(20 * 1024, 'x').join();
      final DateTime newestTime = DateTime.utc(2026, 1, 1);
      final List<InAppNotificationEntity> incoming = List<InAppNotificationEntity>.generate(
        60,
        (index) => notification(
          'notification-$index',
          newestTime.add(Duration(minutes: index)),
          body: body,
          read: index == 59,
        ),
      );
      await local.writeAll(incoming);
      await local.setLastFetchAtUtc(fetchedAt);

      await local.upsertAll(<InAppNotificationEntity>[incoming.last.copyWith(read: false)]);

      final List<InAppNotificationEntity> retained = await local.readAll();
      expect(retained, isNotEmpty);
      expect(retained.length, lessThan(60));
      expect(retained.first.id, 'notification-59');
      expect(retained.any((item) => item.id == 'notification-0'), isFalse);
      expect(retained.first.read, isTrue);
      expect(await local.lastFetchAtUtc(), fetchedAt);
      final record = await store.read('owner:YWNjb3VudC1h');
      expect(record, isNotNull);
      final File recordFile = (await storeDirectory.list().toList()).whereType<File>().single;
      expect(await recordFile.length(), lessThanOrEqualTo(900 * 1024));
    },
  );

  test('notification retention also enforces its item count bound', () async {
    final Directory storeDirectory = Directory('${directory.path}/item_cap')..createSync();
    final local = NotificationsLocalDataSource.withStore(
      DurableJsonStore('notifications_item_cap', directory: storeDirectory),
    )..setOwner('account-a');
    final DateTime createdAt = DateTime.utc(2026, 1, 1);
    final List<InAppNotificationEntity> items = List<InAppNotificationEntity>.generate(
      510,
      (index) => notification('notification-$index', createdAt.add(Duration(minutes: index))),
    );

    await local.writeAll(items);

    final List<InAppNotificationEntity> retained = await local.readAll();
    expect(retained, hasLength(500));
    expect(retained.first.id, 'notification-509');
    expect(retained.last.id, 'notification-10');
  });

  test('notification byte bound includes the full envelope and JSON escaping near the limit', () async {
    final Directory storeDirectory = Directory('${directory.path}/escaped_byte_cap')..createSync();
    final DurableJsonStore store = DurableJsonStore('notifications_escaped_byte_cap', directory: storeDirectory);
    final NotificationsLocalDataSource local = NotificationsLocalDataSource.withStore(store)..setOwner('account-a');
    const String escapedBlock = 'é\n"🙂';
    final DateTime start = DateTime.utc(2026, 1, 1);
    final List<InAppNotificationEntity> items = List<InAppNotificationEntity>.generate(4, (index) {
      final String content = List<String>.filled(22000 + index * 37, escapedBlock).join();
      return InAppNotificationEntity(
        id: 'unicode-$index',
        title: 'title-$index-${List<String>.filled(index + 1, 'x').join()}',
        pageName: 'page-$index',
        body: content,
        imageUrl: 'https://example.test/$index?caption=${Uri.encodeComponent(content.substring(0, 8))}',
        arguments: <Object>[
          'arg-$index',
          <String, Object?>{'nested': content.substring(0, index + 1)},
        ],
        url: 'https://example.test/$index',
        createdAt: start.add(Duration(minutes: index)),
        read: index.isOdd,
        route: 'route-$index-${List<String>.filled(index * 2, 'r').join()}',
        wallId: 'wall-$index',
        followerEmail: 'creator$index@example.test',
      );
    });

    await local.setLastFetchAtUtc(DateTime.utc(2026, 10, 17));
    await local.writeAll(items);

    final List<InAppNotificationEntity> retained = await local.readAll();
    final File recordFile = (await storeDirectory.list().toList()).whereType<File>().single;
    final int encodedBytes = await recordFile.length();
    expect(encodedBytes, lessThanOrEqualTo(900 * 1024));
    expect(encodedBytes, greaterThan(850 * 1024));
    expect(retained.map((item) => item.id), <String>['unicode-3', 'unicode-2', 'unicode-1', 'unicode-0']);
    expect(await local.lastFetchAtUtc(), DateTime.utc(2026, 10, 17));
  });

  test('adding a fetch cursor keeps an exact-cap notification record within the byte bound', () async {
    final Directory storeDirectory = Directory('${directory.path}/cursor_byte_cap')..createSync();
    final DurableJsonStore store = DurableJsonStore('notifications_cursor_byte_cap', directory: storeDirectory);
    final NotificationsLocalDataSource local = NotificationsLocalDataSource.withStore(store)..setOwner('account-a');
    final DateTime createdAt = DateTime.utc(2026, 1, 1);
    const int byteCap = 900 * 1024;
    var body = List<String>.filled(800 * 1024, 'x').join();

    Future<int> writeBodyAndMeasure() async {
      await local.writeAll(<InAppNotificationEntity>[notification('near-cap', createdAt, body: body)]);
      final File recordFile = (await storeDirectory.list().toList()).whereType<File>().single;
      return recordFile.length();
    }

    var encodedBytes = await writeBodyAndMeasure();
    body = '$body${List<String>.filled(byteCap - encodedBytes, 'x').join()}';
    encodedBytes = await writeBodyAndMeasure();
    expect(encodedBytes, byteCap);
    expect(await local.readAll(), hasLength(1));

    final DateTime fetchedAt = DateTime.utc(2026, 10, 17);
    await local.setLastFetchAtUtc(fetchedAt);

    final File writtenRecord = (await storeDirectory.list().toList()).whereType<File>().single;
    expect(await writtenRecord.length(), lessThanOrEqualTo(byteCap));
    expect(await local.lastFetchAtUtc(), fetchedAt);
  });

  test('an oversized notification is skipped without blocking smaller inbox records', () async {
    final Directory storeDirectory = Directory('${directory.path}/oversized')..createSync();
    final local = NotificationsLocalDataSource.withStore(
      DurableJsonStore('notifications_oversized_item', directory: storeDirectory),
    )..setOwner('account-a');
    final DateTime now = DateTime.utc(2026, 10, 17);

    await local.upsertAll(<InAppNotificationEntity>[
      notification('small', now),
      notification(
        'oversized',
        now.add(const Duration(minutes: 1)),
        body: List<String>.filled(1024 * 1024, 'x').join(),
      ),
    ]);

    expect((await local.readAll()).map((item) => item.id), <String>['small']);
  });
}
