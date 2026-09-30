import 'dart:async';

import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_firebase_messaging.dart';
import '../support/fake_firestore_client.dart';

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
