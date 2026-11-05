import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/followed_topics/data/followed_topics_store.dart';
import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class _BlockingClearClient extends _SessionTransactionClient {
  final Completer<void> clearGate = Completer<void>();

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction transaction) action, {
    required String sourceTag,
    required String collection,
    String? docId,
  }) async {
    await clearGate.future;
    return super.runTransaction(action, sourceTag: sourceTag, collection: collection, docId: docId);
  }
}

class _SessionTransactionClient extends FakeFirestoreClient {
  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction transaction) action, {
    required String sourceTag,
    required String collection,
    String? docId,
  }) => action(_SessionTransaction(this));
}

class _SessionTransaction extends Fake implements FirestoreTransaction {
  _SessionTransaction(this.client);
  final FakeFirestoreClient client;

  @override
  Future<Map<String, dynamic>?> getDoc(String collection, String id) async => client.docs[collection]?[id];

  @override
  void setDoc(String collection, String id, Map<String, dynamic> data, {bool merge = false}) {
    unawaited(client.setDoc(collection, id, data, merge: merge, sourceTag: 'test.transaction'));
  }
}

class _FailingSyncedMarkerStore extends InMemoryLocalStore {
  bool failSyncedMarker = false;

  @override
  Future<void> set(String key, Object? value) async {
    if (failSyncedMarker && key == 'settings.fcmTokenSynced') throw StateError('marker write failed');
    await super.set(key, value);
  }
}

class _FailingWriteClient extends FakeFirestoreClient {
  bool failWrites = false;

  @override
  Future<void> setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
    required String sourceTag,
  }) {
    if (failWrites) return Future<void>.error(StateError('offline'));
    return super.setDoc(collection, id, data, merge: merge, sourceTag: sourceTag);
  }
}

void main() {
  setUp(() async {
    await FcmTokenService.instance.cancelAndWait();
    await FcmTokenService.instance.invalidateTokenForSignOut(messaging: FakeFirebaseMessaging());
  });

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

  test('does not bind a token to a new user until failed sign-out invalidation succeeds', () async {
    await getIt.reset();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set('fcmTokenSynced', 'old-user|old-token');
    await settings.set('fcmTokenRotationV2', 'old-user');
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    addTearDown(getIt.reset);
    String currentToken = 'old-token';
    final FakeFirebaseMessaging messaging = FakeFirebaseMessaging();
    messaging.getTokenHandler = () async => currentToken;
    messaging.deleteTokenHandler = () => Future<void>.error(StateError('offline'));
    final FakeFirestoreClient client = FakeFirestoreClient();
    final FcmTokenService service = FcmTokenService.instance;

    await expectLater(service.invalidateTokenForSignOut(messaging: messaging), throwsStateError);
    await service.syncToken(userId: 'new-user', messaging: messaging, client: client);
    expect(client.writes, isEmpty);
    expect(settings.get<bool>('fcmTokenInvalidationPendingV1'), isTrue);
    expect(settings.get<String>('fcmTokenRotationV2'), 'old-user');

    messaging
      ..deleteTokenHandler = () async {}
      ..getTokenHandler = () async => currentToken = 'new-token';
    await service.syncToken(userId: 'new-user', messaging: messaging, client: client);
    expect(client.writes.single.data?['fcmToken'], 'new-token');
  });

  test('rotates a token before first-version binding or a different account binding', () async {
    await getIt.reset();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set('fcmTokenSynced', 'old-user|same-token');
    await settings.set('fcmTokenRotationV2', 'old-user');
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    addTearDown(getIt.reset);
    final FakeFirebaseMessaging messaging = FakeFirebaseMessaging()..getTokenHandler = () async => 'new-token';
    final FakeFirestoreClient client = FakeFirestoreClient();

    await FcmTokenService.instance.syncToken(userId: 'new-user', messaging: messaging, client: client);

    expect(messaging.deleteTokenCalls, 1);
    expect(client.writes.single.data?['fcmToken'], 'new-token');
    expect(settings.get<String>('fcmTokenRotationV2'), 'new-user');
  });

  test('a new binding version rotates before registering after upgrade', () async {
    await getIt.reset();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    addTearDown(getIt.reset);
    final FakeFirebaseMessaging messaging = FakeFirebaseMessaging()..getTokenHandler = () async => 'fresh-token';
    final FakeFirestoreClient client = FakeFirestoreClient();

    await FcmTokenService.instance.syncToken(userId: 'existing-user', messaging: messaging, client: client);

    expect(messaging.deleteTokenCalls, 1);
    expect(client.writes.single.data?['fcmToken'], 'fresh-token');
  });

  test('an old same-token sync marker is rewritten with localization version two', () async {
    await getIt.reset();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set('fcmTokenSynced', 'uid1|same-token');
    await settings.set('fcmTokenRotationV2', 'uid1');
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    addTearDown(getIt.reset);
    final FakeFirebaseMessaging messaging = FakeFirebaseMessaging()..getTokenHandler = () async => 'same-token';
    final FakeFirestoreClient client = FakeFirestoreClient();

    await FcmTokenService.instance.syncToken(userId: 'uid1', messaging: messaging, client: client);

    expect(messaging.deleteTokenCalls, 0);
    expect(client.writes, hasLength(1));
    expect(client.writes.single.data?['notificationLocalizationVersion'], 2);
    expect(client.writes.single.data?['notificationLocalizationToken'], 'same-token');
    expect(settings.get<String>('fcmTokenSynced'), 'uid1|same-token|digest_v2|posts:true|folders:true|topics:true');
  });

  test('writes localization version two with the current token', () async {
    final FakeFirestoreClient client = FakeFirestoreClient();

    await FcmTokenService.instance.syncToken(
      userId: 'uid1',
      messaging: FakeFirebaseMessaging()..getTokenHandler = () async => 'current-token',
      client: client,
    );

    expect(client.writes.single.data?['notificationLocalizationVersion'], 2);
    expect(client.writes.single.data?['notificationLocalizationToken'], 'current-token');
  });

  test('same-token sync retries a Posts opt-out after the preference write failed', () async {
    await getIt.reset();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set('fcmTokenRotationV2', 'uid1');
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    addTearDown(getIt.reset);
    final FakeFirebaseMessaging messaging = FakeFirebaseMessaging()..getTokenHandler = () async => 'same-token';
    final _FailingWriteClient client = _FailingWriteClient();
    final FcmTokenService service = FcmTokenService.instance;

    await service.syncToken(userId: 'uid1', messaging: messaging, client: client);
    await settings.set('postsSubscriber', false);
    client.failWrites = true;
    await service.savePostAlerts(userId: 'uid1', enabled: false, client: client);
    client
      ..failWrites = false
      ..writes.clear();

    await service.syncToken(userId: 'uid1', messaging: messaging, client: client);

    expect(client.writes.single.data?['postAlerts'], isFalse);
  });

  test('same-token sync keeps Posts disabled when Followers is off', () async {
    await getIt.reset();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set('fcmTokenRotationV2', 'uid1');
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    addTearDown(getIt.reset);
    final FakeFirebaseMessaging messaging = FakeFirebaseMessaging()..getTokenHandler = () async => 'same-token';
    final FakeFirestoreClient client = FakeFirestoreClient();
    final FcmTokenService service = FcmTokenService.instance;

    await service.syncToken(userId: 'uid1', messaging: messaging, client: client);
    await settings.set('followersSubscriber', false);
    client.writes.clear();

    await service.syncToken(userId: 'uid1', messaging: messaging, client: client);

    expect(client.writes.firstWhere((write) => write.data?['fcmToken'] == 'same-token').data?['postAlerts'], isFalse);
  });

  test('a new account waits for a delayed sign-out token invalidation', () async {
    final Completer<void> deleteGate = Completer<void>();
    final Completer<void> getStarted = Completer<void>();
    final Completer<String?> token = Completer<String?>();
    final FakeFirebaseMessaging messaging = FakeFirebaseMessaging();
    messaging.deleteTokenHandler = () => deleteGate.future;
    messaging.getTokenHandler = () {
      getStarted.complete();
      return token.future;
    };
    final FakeFirestoreClient client = FakeFirestoreClient();
    final FcmTokenService service = FcmTokenService.instance;

    await service.cancelAndWait();
    final Future<void> invalidation = service.invalidateTokenForSignOut(messaging: messaging);
    final Future<void> sync = service.syncToken(userId: 'new-user', messaging: messaging, client: client);
    await Future<void>.delayed(Duration.zero);
    expect(client.writes, isEmpty);
    expect(getStarted.isCompleted, isFalse);

    deleteGate.complete();
    await invalidation;
    await getStarted.future;
    token.complete('new-token');
    await sync;
    expect(client.writes.single.data?['fcmToken'], 'new-token');
  });

  test('a token refresh after APNs readiness completes the deferred user binding', () async {
    await getIt.reset();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    addTearDown(getIt.reset);
    final StreamController<String> refreshes = StreamController<String>();
    String? currentToken;
    final FakeFirebaseMessaging messaging = FakeFirebaseMessaging()
      ..tokenRefreshes = refreshes.stream
      ..getTokenHandler = () async => currentToken;
    final FakeFirestoreClient client = FakeFirestoreClient();
    final FcmTokenService service = FcmTokenService.instance;

    await service.syncToken(userId: 'ios-user', messaging: messaging, client: client);
    service.listenForTokenRefresh(userId: 'ios-user', messaging: messaging, client: client);
    currentToken = 'apns-ready-token';
    refreshes.add(currentToken);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await service.cancelAndWait();
    await refreshes.close();

    expect(messaging.deleteTokenCalls, 1);
    expect(client.writes.single.data?['fcmToken'], 'apns-ready-token');
    expect(settings.get<String>('fcmTokenRotationV2'), 'ios-user');
  });

  test('a new user cannot register until delayed sign-out storage cleanup finishes', () async {
    await getIt.reset();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set('fcmTokenSynced', 'old-user|old-token');
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    addTearDown(getIt.reset);
    final Completer<void> getStarted = Completer<void>();
    final FakeFirebaseMessaging messaging = FakeFirebaseMessaging()
      ..getTokenHandler = () async {
        getStarted.complete();
        return 'new-token';
      };
    final _BlockingClearClient client = _BlockingClearClient();
    final FcmTokenService service = FcmTokenService.instance;

    await service.cancelAndWait();
    final Future<void> signOutCleanup = service.invalidateTokenForSignOut(
      userId: 'old-user',
      messaging: messaging,
      client: client,
    );
    final Future<void> sync = service.syncToken(userId: 'new-user', messaging: messaging, client: client);
    await Future<void>.delayed(Duration.zero);
    expect(getStarted.isCompleted, isFalse);

    client.clearGate.complete();
    await signOutCleanup;
    await getStarted.future;
    await sync;
    expect(client.writes.where((write) => write.collection == 'usersv2/new-user/private'), hasLength(1));
  });

  test('sign-out clears local followed-topic seen state for the departing account', () async {
    await getIt.reset();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set('followed_topics.seen.uid1.category:Pastel', 100);
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<FollowedTopicsStore>(FollowedTopicsStore(settings, FakeFirestoreClient()));
    addTearDown(getIt.reset);

    await FcmTokenService.instance.invalidateTokenForSignOut(
      userId: 'uid1',
      messaging: FakeFirebaseMessaging(),
      client: _SessionTransactionClient(),
    );

    expect(settings.get<int?>('followed_topics.seen.uid1.category:Pastel'), isNull);
  });

  test('failed token invalidation still clears the departing accounts local topic state', () async {
    await getIt.reset();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set('followed_topics.seen.uid1.category:Pastel', 100);
    await settings.set('followed_topics.seen.uid2.category:Pastel', 200);
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<FollowedTopicsStore>(FollowedTopicsStore(settings, FakeFirestoreClient()));
    addTearDown(getIt.reset);

    await expectLater(
      FcmTokenService.instance.invalidateTokenForSignOut(
        userId: 'uid1',
        messaging: FakeFirebaseMessaging()..deleteTokenHandler = () async => throw StateError('offline'),
        client: _SessionTransactionClient(),
      ),
      throwsStateError,
    );

    expect(settings.get<int?>('followed_topics.seen.uid1.category:Pastel'), isNull);
    expect(settings.get<int>('followed_topics.seen.uid2.category:Pastel'), 200);
  });

  test('sign-out clears the current token when saving its local marker failed', () async {
    await getIt.reset();
    final _FailingSyncedMarkerStore local = _FailingSyncedMarkerStore();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(local);
    await settings.set('fcmTokenSynced', 'uid1|old-token|digest_v2');
    await settings.set('fcmTokenRotationV2', 'uid1');
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    addTearDown(getIt.reset);
    final _SessionTransactionClient client = _SessionTransactionClient();
    final FcmTokenService service = FcmTokenService.instance;
    await service.cancelAndWait();
    await service.clearSyncedToken();
    await settings.set('fcmTokenSynced', 'uid1|old-token|digest_v2');
    local.failSyncedMarker = true;

    await service.syncToken(
      userId: 'uid1',
      messaging: FakeFirebaseMessaging()..getTokenHandler = () async => 'new-token',
      client: client,
    );
    await service.cancelAndWait();
    await service.clearSyncedToken();
    await expectLater(
      service.invalidateTokenForSignOut(
        userId: 'uid1',
        messaging: FakeFirebaseMessaging()..deleteTokenHandler = () async => throw StateError('offline'),
        client: client,
      ),
      throwsStateError,
    );

    expect(client.writes.last.data?['fcmToken'], isA<FieldValue>());
  });

  test('waits for an already-started token refresh write before returning', () async {
    final StreamController<String> refreshes = StreamController<String>();
    final FakeFirebaseMessaging messaging = FakeFirebaseMessaging()
      ..tokenRefreshes = refreshes.stream
      ..getTokenHandler = () async => 'initial-token';
    final _BlockingWriteClient client = _BlockingWriteClient();
    final FcmTokenService service = FcmTokenService.instance;
    await service.syncToken(userId: 'uid1', messaging: messaging, client: FakeFirestoreClient());
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
    expect(client.writes.single.data, <String, dynamic>{
      'fcmToken': 'refreshed-token',
      'notificationLocalizationVersion': 2,
      'notificationLocalizationToken': 'refreshed-token',
      'fcmTokenBindingVersion': 1,
      'fcmTokenBindingToken': 'refreshed-token',
      'postAlerts': true,
      'postAlertsToken': 'refreshed-token',
      'folderAlerts': true,
      'folderAlertsToken': 'refreshed-token',
      'topicAlerts': true,
      'topicAlertsToken': 'refreshed-token',
    });
  });

  test('the Posts switch is stored where the follow digest reads it', () async {
    final client = _MergeRecordingClient();

    await FcmTokenService.instance.savePostAlerts(userId: 'uid1', enabled: false, client: client);

    final write = client.writes.single;
    expect((write.collection, write.id), ('usersv2/uid1/private', 'session'));
    expect(client.merged, isTrue);
    expect(write.data, <String, dynamic>{'postAlerts': false});
  });

  test('the Topics switch is stored where the topic digest reads it', () async {
    final client = _MergeRecordingClient();

    await FcmTokenService.instance.saveTopicAlerts(userId: 'uid1', enabled: false, client: client);

    final write = client.writes.single;
    expect((write.collection, write.id), ('usersv2/uid1/private', 'session'));
    expect(client.merged, isTrue);
    expect(write.data, <String, dynamic>{'topicAlerts': false});
  });

  test('token sync writes the Topics switch off with the token when the switch is off', () async {
    await getIt.reset();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set('topicsSubscriber', false);
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    addTearDown(getIt.reset);
    final client = FakeFirestoreClient();

    await FcmTokenService.instance.syncToken(
      userId: 'uid1',
      messaging: FakeFirebaseMessaging()..getTokenHandler = () async => 'tok',
      client: client,
    );

    final write = client.writes.firstWhere((w) => w.data?['fcmToken'] == 'tok');
    expect(write.data?['topicAlerts'], isFalse);
    expect(write.data?['topicAlertsToken'], 'tok');
  });

  test('token sync opts this build into the digest, off when Followers is off, bound to the token', () async {
    await getIt.reset();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set('followersSubscriber', false);
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    addTearDown(getIt.reset);
    final client = FakeFirestoreClient();

    await FcmTokenService.instance.syncToken(
      userId: 'uid1',
      messaging: FakeFirebaseMessaging()..getTokenHandler = () async => 'tok',
      client: client,
    );

    final write = client.writes.firstWhere((w) => w.data?['fcmToken'] == 'tok');
    expect(write.data?['postAlerts'], isFalse);
    expect(write.data?['postAlertsToken'], 'tok');
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

  group('token binding sync', () {
    late FakeFirestoreClient client;

    Future<void> sync(String userId, String token) => FcmTokenService.instance.syncToken(
      userId: userId,
      messaging: FakeFirebaseMessaging()..getTokenHandler = () async => token,
      client: client,
    );

    int tokenWrites() => client.writes.where((w) => w.data?['fcmToken'] != null).length;

    setUp(() async {
      await getIt.reset();
      getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
      client = FakeFirestoreClient();
    });
    tearDown(getIt.reset);

    test('the same user and token restore the active binding across launches', () async {
      await sync('uid1', 'tok');
      client.docs['usersv2/uid1/private']!['session']!['fcmToken'] = 'other-device';
      await sync('uid1', 'tok');

      expect(client.docs['usersv2/uid1/private']!['session']!['fcmToken'], 'tok');
      expect(tokenWrites(), 2);
    });

    test('same-token sync restores the local topic opt-out after another device changes the session', () async {
      final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
      await settings.set('topicsSubscriber', false);
      await sync('uid1', 'tok');
      client.docs['usersv2/uid1/private']!['session']!['topicAlerts'] = true;

      await sync('uid1', 'tok');

      expect(client.docs['usersv2/uid1/private']!['session']!['topicAlerts'], isFalse);
    });

    test('sign-out does not clear a different device token bound after this device synced', () async {
      client = _SessionTransactionClient();
      await sync('uid1', 'tok');
      final Map<String, dynamic> session = client.docs['usersv2/uid1/private']!['session']!;
      session.addAll(<String, dynamic>{'fcmToken': 'other-device', 'fcmTokenBindingToken': 'other-device'});

      await FcmTokenService.instance.invalidateTokenForSignOut(
        userId: 'uid1',
        messaging: FakeFirebaseMessaging(),
        client: client,
      );

      expect(client.docs['usersv2/uid1/private']!['session']!['fcmToken'], 'other-device');
      expect(client.docs['usersv2/uid1/private']!['session']!['fcmTokenBindingToken'], 'other-device');
    });

    test('sign-out clears its own token binding', () async {
      client = _SessionTransactionClient();
      await sync('uid1', 'tok');

      await FcmTokenService.instance.cancelAndWait();
      await FcmTokenService.instance.clearSyncedToken();

      await FcmTokenService.instance.invalidateTokenForSignOut(
        userId: 'uid1',
        messaging: FakeFirebaseMessaging(),
        client: client,
      );

      expect(client.writes, hasLength(2));
      expect(client.writes.last.data?['fcmToken'], isA<FieldValue>());
      expect(getIt<SettingsLocalDataSource>().get<String?>('fcmTokenSynced'), isNull);
    });

    test('sign-out uses the persisted binding when no in-memory binding remains', () async {
      client = _SessionTransactionClient();
      await getIt<SettingsLocalDataSource>().set('fcmTokenSynced', 'uid1|tok|digest_v2');
      client.docs['usersv2/uid1/private'] = <String, Map<String, dynamic>>{
        'session': <String, dynamic>{'fcmToken': 'tok'},
      };

      await FcmTokenService.instance.cancelAndWait();
      await FcmTokenService.instance.clearSyncedToken();
      await getIt<SettingsLocalDataSource>().delete('fcmTokenSynced');

      await FcmTokenService.instance.invalidateTokenForSignOut(
        userId: 'uid1',
        messaging: FakeFirebaseMessaging(),
        client: client,
      );

      expect(client.writes.single.data?['fcmToken'], isA<FieldValue>());
    });

    test('sign-out does not recreate a session deleted after token sync', () async {
      client = _SessionTransactionClient();
      await sync('uid1', 'tok');
      client.docs['usersv2/uid1/private']!.remove('session');

      await FcmTokenService.instance.invalidateTokenForSignOut(
        userId: 'uid1',
        messaging: FakeFirebaseMessaging(),
        client: client,
      );

      expect(client.docs['usersv2/uid1/private']!.containsKey('session'), isFalse);
      expect(client.writes, hasLength(1));
    });

    test('a changed token writes again', () async {
      await sync('uid1', 'tok');
      await sync('uid1', 'tok2');

      expect(client.writes.map((w) => w.data?['fcmToken']), <Object?>['tok', 'tok2']);
    });

    test('a different user writes the same token again', () async {
      await sync('uid1', 'tok');
      await sync('uid2', 'tok');

      expect(client.writes.map((w) => w.id), <String>['session', 'session']);
      expect(client.writes.map((w) => w.collection), <String>['usersv2/uid1/private', 'usersv2/uid2/private']);
    });

    test('after the synced token is cleared the same token writes again', () async {
      await sync('uid1', 'tok');
      await FcmTokenService.instance.clearSyncedToken();
      await sync('uid1', 'tok');

      expect(tokenWrites(), 2);
    });
  });
}
