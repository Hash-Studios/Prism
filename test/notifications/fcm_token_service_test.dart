import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_firebase_messaging.dart';
import '../support/fake_firestore_client.dart';
import '../support/in_memory_local_store.dart';

class _MergeRecordingClient extends FakeFirestoreClient {
  bool? merged;

  @override
  Future<void> setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
    required String sourceTag,
  }) {
    merged = merge;
    return super.setDoc(collection, id, data, merge: merge, sourceTag: sourceTag);
  }
}

class _BlockingWriteClient extends FakeFirestoreClient {
  final Completer<void> writeGate = Completer<void>();
  bool failAfterGate = false;

  @override
  Future<void> setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
    required String sourceTag,
  }) async {
    await super.setDoc(collection, id, data, merge: merge, sourceTag: sourceTag);
    await writeGate.future;
    if (failAfterGate) throw StateError('write failed');
  }
}

void main() {
  test('the Followers switch is stored where onFollowCreated reads it', () async {
    final client = _MergeRecordingClient();

    await FcmTokenService.instance.saveFollowerAlerts(userId: 'uid1', enabled: false, client: client);

    final write = client.writes.single;
    expect((write.collection, write.id), ('usersv2/uid1/private', 'session'));
    expect(client.merged, isTrue);
    expect(write.data, <String, dynamic>{'followerAlerts': false});
  });

  test('the Recommendations switch is stored where win-back and campaigns read it', () async {
    final client = _MergeRecordingClient();

    await FcmTokenService.instance.saveMarketingPushes(userId: 'uid1', enabled: false, client: client);

    final write = client.writes.single;
    expect((write.collection, write.id), ('usersv2/uid1/private', 'session'));
    expect(client.merged, isTrue);
    expect(write.data, <String, dynamic>{'marketingPushes': false});
  });

  test('saving the Recommendations switch without a signed-in user writes nothing', () async {
    final client = _MergeRecordingClient();

    await FcmTokenService.instance.saveMarketingPushes(userId: ' ', enabled: false, client: client);

    expect(client.writes, isEmpty);
  });

  test('a Recommendations switch turned off before sign-in is carried to the server with the token', () async {
    await getIt.reset();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set('recommendationsSubscriber', false);
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    addTearDown(getIt.reset);
    final client = FakeFirestoreClient();

    await FcmTokenService.instance.syncToken(
      userId: 'uid1',
      messaging: FakeFirebaseMessaging()..getTokenHandler = () async => 'tok',
      client: client,
    );

    expect(client.writes.where((w) => w.data?['marketingPushes'] == false), hasLength(1));
  });

  test('does not persist a token fetched after sign-out begins', () async {
    final Completer<String?> token = Completer<String?>();
    final FakeFirebaseMessaging messaging = FakeFirebaseMessaging()..getTokenHandler = () => token.future;
    final FakeFirestoreClient client = FakeFirestoreClient();
    final FcmTokenService service = FcmTokenService.instance;

    final Future<void> sync = service.syncToken(userId: 'uid1', messaging: messaging, client: client);
    await service.cancelAndWait();
    token.complete('late-token');
    await sync;

    expect(client.writes, isEmpty);
  });

  test('waits for an already-started token refresh write before returning', () async {
    final StreamController<String> refreshes = StreamController<String>();
    final FakeFirebaseMessaging messaging = FakeFirebaseMessaging()..tokenRefreshes = refreshes.stream;
    final _BlockingWriteClient client = _BlockingWriteClient();
    final FcmTokenService service = FcmTokenService.instance;
    service.listenForTokenRefresh(userId: 'uid1', messaging: messaging, client: client);
    refreshes.add('refreshed-token');
    await Future<void>.delayed(Duration.zero);

    bool drained = false;
    final Future<void> cancel = service.cancelAndWait().then((_) => drained = true);
    await Future<void>.delayed(Duration.zero);
    expect(drained, isFalse);

    client.writeGate.complete();
    await cancel;
    await refreshes.close();

    expect(drained, isTrue);
    expect(client.writes.single.data, <String, dynamic>{'fcmToken': 'refreshed-token'});
  });

  test('waits for an already-started token sync write before returning', () async {
    final FakeFirebaseMessaging messaging = FakeFirebaseMessaging()..getTokenHandler = () async => 'initial-token';
    final _BlockingWriteClient client = _BlockingWriteClient();
    final FcmTokenService service = FcmTokenService.instance;
    final Future<void> sync = service.syncToken(userId: 'uid1', messaging: messaging, client: client);
    await Future<void>.delayed(Duration.zero);

    bool drained = false;
    final Future<void> cancel = service.cancelAndWait().then((_) => drained = true);
    await Future<void>.delayed(Duration.zero);
    expect(drained, isFalse);

    client.writeGate.complete();
    await cancel;
    await sync;
    expect(drained, isTrue);
  });

  test('continues draining when an in-flight token write fails', () async {
    final FakeFirebaseMessaging messaging = FakeFirebaseMessaging()..getTokenHandler = () async => 'initial-token';
    final _BlockingWriteClient client = _BlockingWriteClient()..failAfterGate = true;
    final FcmTokenService service = FcmTokenService.instance;
    final Future<void> sync = service.syncToken(userId: 'uid1', messaging: messaging, client: client);
    await Future<void>.delayed(Duration.zero);

    final Future<void> cancel = service.cancelAndWait();
    client.writeGate.complete();

    await expectLater(cancel, completes);
    await sync;
  });
}
