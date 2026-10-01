import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/notifications/notification_pref_keys.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_local_store.dart';

class _FakeMessaging implements FirebaseMessaging {
  final List<String> subscribed = <String>[];
  final List<String> unsubscribed = <String>[];
  String? token = 'fcm-token';
  Object? tokenError;
  bool failSubscribe = false;

  @override
  Future<String?> getToken({String? vapidKey}) async {
    if (tokenError != null) throw tokenError!;
    return token;
  }

  @override
  Future<String?> getAPNSToken() async => 'apns';

  @override
  Future<void> subscribeToTopic(String topic) async {
    if (failSubscribe) throw StateError('network');
    subscribed.add(topic);
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async => unsubscribed.add(topic);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SettingsLocalDataSource settings;
  late _FakeMessaging messaging;

  setUp(() {
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    messaging = _FakeMessaging();
  });

  Future<void> sync({String userId = 'uid1', bool premium = false}) => syncPushTopics(
    messaging,
    settings,
    userId: userId,
    email: 'ana@example.com',
    premium: premium,
    following: const <String>['lee@example.com'],
  );

  test('subscribes to every topic the server sends to', () async {
    await sync();

    expect(
      messaging.subscribed,
      unorderedEquals(<String>['recommendations', 'wall_of_the_day', 'free', 'u_uid1', 'ana', 'lee_posts']),
    );
    expect(messaging.unsubscribed, <String>['premium']);
  });

  test('runs once per token, user and tier', () async {
    await sync();
    messaging.subscribed.clear();

    await sync();
    expect(messaging.subscribed, isEmpty);

    await sync(premium: true);
    expect(messaging.subscribed, contains('premium'));
    expect(messaging.unsubscribed, contains('free'));

    messaging
      ..subscribed.clear()
      ..token = 'new-token';
    await sync(premium: true);
    expect(messaging.subscribed, isNotEmpty);
  });

  test('respects switched-off preferences and signed-out state', () async {
    await settings.set(NotificationPrefKeys.recommendations, false);
    await settings.set(PersistenceKeys.notifWotd, false);
    await settings.set(NotificationPrefKeys.posts, false);

    await sync(userId: '');

    expect(messaging.subscribed, <String>['free']);
  });

  test('retries on the next launch when there is no token or a subscribe fails', () async {
    messaging.tokenError = Exception('apns-token-not-set');
    await sync();
    expect(messaging.subscribed, isEmpty);

    messaging
      ..tokenError = null
      ..failSubscribe = true;
    await sync();

    messaging.failSubscribe = false;
    await sync();
    expect(messaging.subscribed, contains('u_uid1'));
  });
}
