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
  Future<String?> getToken({String? vapidKey, String? serviceWorkerScriptPath}) async {
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
      unorderedEquals(<String>['recommendations', wotdBucketTopic(), 'free', 'u_uid1', 'ana', 'lee_posts']),
    );
    expect(messaging.unsubscribed, unorderedEquals(<String>['premium', 'wall_of_the_day']));
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

  group('wall of the day buckets', () {
    const Duration ist = Duration(hours: 5, minutes: 30);

    test('names the bucket by UTC offset in 15 minute steps', () {
      expect(wotdBucketTopic(ist), 'wall_of_the_day_utc_p0530');
      expect(wotdBucketTopic(const Duration(hours: 5, minutes: 45)), 'wall_of_the_day_utc_p0545');
      expect(wotdBucketTopic(Duration.zero), 'wall_of_the_day_utc_p0000');
      expect(wotdBucketTopic(const Duration(hours: -3, minutes: -30)), 'wall_of_the_day_utc_m0330');
      expect(wotdBucketTopic(const Duration(hours: -9, minutes: -7)), 'wall_of_the_day_utc_m0900');
      expect(wotdBucketTopic(const Duration(hours: 16)), 'wall_of_the_day_utc_p1400');
    });

    test('every bucket topic is a valid FCM topic name', () {
      final RegExp valid = RegExp(r'^[a-zA-Z0-9\-_.~%]+$');
      for (int minutes = -720; minutes <= 840; minutes += 15) {
        expect(wotdBucketTopic(Duration(minutes: minutes)), matches(valid));
      }
    });

    test('joining the bucket leaves the global topic and the old bucket', () async {
      await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 't', offset: ist);
      expect(messaging.subscribed, <String>['wall_of_the_day_utc_p0530']);
      expect(messaging.unsubscribed, <String>['wall_of_the_day']);

      messaging
        ..subscribed.clear()
        ..unsubscribed.clear();
      await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 't', offset: Duration.zero);
      expect(messaging.subscribed, <String>['wall_of_the_day_utc_p0000']);
      expect(messaging.unsubscribed, <String>['wall_of_the_day', 'wall_of_the_day_utc_p0530']);
    });

    test('turning it off leaves both the global topic and the bucket', () async {
      await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 't', offset: ist);
      messaging.unsubscribed.clear();

      await setWotdTopics(messaging, settings, subscribed: false, sourceTag: 't', offset: Duration.zero);
      expect(messaging.unsubscribed, unorderedEquals(<String>['wall_of_the_day', 'wall_of_the_day_utc_p0530']));
    });

    test('a failed join is retried and does not leave the global topic', () async {
      messaging.failSubscribe = true;
      expect(await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 't', offset: ist), isFalse);
      expect(messaging.unsubscribed, isEmpty);

      messaging.failSubscribe = false;
      await refreshWotdTopics(messaging, settings, offset: ist);
      expect(messaging.subscribed, <String>['wall_of_the_day_utc_p0530']);
    });

    test('refresh moves the device only when the offset changed and the push is on', () async {
      await refreshWotdTopics(messaging, settings, offset: ist);
      messaging
        ..subscribed.clear()
        ..unsubscribed.clear();

      await refreshWotdTopics(messaging, settings, offset: ist);
      expect(messaging.subscribed, isEmpty);

      await refreshWotdTopics(messaging, settings, offset: const Duration(hours: 1));
      expect(messaging.subscribed, <String>['wall_of_the_day_utc_p0100']);
      expect(messaging.unsubscribed, contains('wall_of_the_day_utc_p0530'));

      await settings.set(PersistenceKeys.notifWotd, false);
      messaging.subscribed.clear();
      await refreshWotdTopics(messaging, settings, offset: ist);
      expect(messaging.subscribed, isEmpty);
    });
  });
}
