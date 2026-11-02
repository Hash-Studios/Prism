import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/notifications/notification_pref_keys.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_firestore_client.dart';
import '../support/in_memory_local_store.dart';

String _nativeTopic(String topic) => '${topic}_loc_v1';

class _FakeMessaging implements FirebaseMessaging {
  final List<String> subscribed = <String>[];
  final List<String> unsubscribed = <String>[];
  final List<String> unsubscribeAttempts = <String>[];
  String? token = 'fcm-token';
  Object? tokenError;
  bool failSubscribe = false;
  final Set<String> failUnsubscribeFor = <String>{};

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
  Future<void> unsubscribeFromTopic(String topic) async {
    unsubscribeAttempts.add(topic);
    if (failUnsubscribeFor.contains(topic)) throw StateError('network');
    unsubscribed.add(topic);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SettingsLocalDataSource settings;
  late _FakeMessaging messaging;

  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<FirestoreClient>(FakeFirestoreClient());
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    messaging = _FakeMessaging();
    await settings.set(NotificationPrefKeys.posts, false);
  });

  tearDown(() => getIt.reset());

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
      unorderedEquals(<String>[
        'recommendations_loc_v1',
        'drops_loc_v1',
        '${wotdBucketTopic()}_loc_v1',
        'free_loc_v1',
        'ana_loc_v1',
      ]),
    );
    expect(
      messaging.unsubscribed,
      unorderedEquals(<String>[
        'recommendations',
        'drops',
        wotdBucketTopic(),
        'free',
        'premium',
        'premium_loc_v1',
        'u_uid1',
        'u_uid1_loc_v1',
        'ana',
        'lee_posts',
        'lee_posts_loc_v1',
        'wall_of_the_day',
        'wall_of_the_day_loc_v1',
      ]),
    );
  });

  test('runs once per token, user and tier', () async {
    await sync();
    messaging.subscribed.clear();

    await sync();
    expect(messaging.subscribed, isEmpty);

    await sync(premium: true);
    expect(messaging.subscribed, contains('premium_loc_v1'));
    expect(messaging.unsubscribed, contains('free'));
    expect(messaging.unsubscribed, contains('free_loc_v1'));

    messaging
      ..subscribed.clear()
      ..token = 'new-token';
    await sync(premium: true);
    expect(messaging.subscribed, isNotEmpty);
  });

  test('retries legacy creator topic cleanup before recording migration complete', () async {
    messaging.failUnsubscribeFor.add('lee_posts');

    await sync();
    expect(messaging.unsubscribeAttempts, contains('lee_posts'));
    expect(messaging.unsubscribed, isNot(contains('lee_posts')));

    messaging.failUnsubscribeFor.clear();
    final int beforeRetry = messaging.unsubscribeAttempts.where((topic) => topic == 'lee_posts').length;
    await sync();
    expect(messaging.unsubscribeAttempts.where((topic) => topic == 'lee_posts'), hasLength(beforeRetry + 1));

    final int afterSuccess = messaging.unsubscribeAttempts.length;
    await sync();
    expect(messaging.unsubscribeAttempts, hasLength(afterSuccess));
  });

  test('an old completed sync marker does not skip the UID-topic migration sync', () async {
    await settings.set('pushTopicsSyncedForLocV2', 'fcm-token|uid1|free');

    await sync();

    expect(messaging.subscribed, contains('recommendations_loc_v1'));
    expect(messaging.unsubscribeAttempts, contains('lee_posts'));
  });

  test('respects switched-off preferences and signed-out state', () async {
    await settings.set(NotificationPrefKeys.recommendations, false);
    await settings.set(NotificationPrefKeys.drops, false);
    await settings.set(PersistenceKeys.notifWotd, false);
    await settings.set(NotificationPrefKeys.posts, false);

    await sync(userId: '');

    expect(messaging.subscribed, <String>['free_loc_v1']);
  });

  test('removes UID creator topics even when Posts is switched off', () async {
    final FakeFirestoreClient client = FakeFirestoreClient(
      onQuery: (_) => <FakeDocRow>[(id: 'creator-uid', data: <String, dynamic>{})],
    );
    await getIt.reset();
    getIt.registerSingleton<FirestoreClient>(client);
    addTearDown(getIt.reset);

    await sync();

    expect(messaging.unsubscribed, containsAll(<String>['posts_creator-uid', 'posts_creator-uid_loc_v1']));
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
    expect(messaging.subscribed, isNot(contains('u_uid1_loc_v1')));
    expect(messaging.unsubscribed, containsAll(<String>['u_uid1', 'u_uid1_loc_v1']));
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
      expect(messaging.subscribed, <String>[_nativeTopic('wall_of_the_day_utc_p0530')]);
      expect(messaging.unsubscribed, <String>[
        'wall_of_the_day_utc_p0530',
        'wall_of_the_day',
        _nativeTopic('wall_of_the_day'),
      ]);

      messaging
        ..subscribed.clear()
        ..unsubscribed.clear();
      await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 't', offset: Duration.zero);
      expect(messaging.subscribed, <String>[_nativeTopic('wall_of_the_day_utc_p0000')]);
      expect(
        messaging.unsubscribed,
        unorderedEquals(<String>[
          'wall_of_the_day',
          _nativeTopic('wall_of_the_day'),
          'wall_of_the_day_utc_p0000',
          'wall_of_the_day_utc_p0530',
          _nativeTopic('wall_of_the_day_utc_p0530'),
        ]),
      );
    });

    test('turning it off leaves both the global topic and the bucket', () async {
      await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 't', offset: ist);
      messaging.unsubscribed.clear();

      await setWotdTopics(messaging, settings, subscribed: false, sourceTag: 't', offset: Duration.zero);
      expect(
        messaging.unsubscribed,
        unorderedEquals(<String>[
          'wall_of_the_day',
          _nativeTopic('wall_of_the_day'),
          'wall_of_the_day_utc_p0530',
          _nativeTopic('wall_of_the_day_utc_p0530'),
        ]),
      );
    });

    test('a failed join is retried and does not leave the global topic', () async {
      messaging.failSubscribe = true;
      expect(await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 't', offset: ist), isFalse);
      expect(messaging.unsubscribed, isEmpty);

      messaging.failSubscribe = false;
      await refreshWotdTopics(messaging, settings, offset: ist);
      expect(messaging.subscribed, <String>[_nativeTopic('wall_of_the_day_utc_p0530')]);
    });

    test('a failed leave of the old bucket is retried by refresh even when the offset did not change', () async {
      await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 't', offset: ist);
      messaging.failUnsubscribeFor.add('wall_of_the_day_utc_p0530');
      messaging.unsubscribed.clear();
      await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 't', offset: Duration.zero);
      expect(messaging.unsubscribed, isNot(contains('wall_of_the_day_utc_p0530')));

      messaging
        ..unsubscribed.clear()
        ..failUnsubscribeFor.clear();
      await refreshWotdTopics(messaging, settings, offset: Duration.zero);
      expect(messaging.unsubscribed, <String>['wall_of_the_day_utc_p0530', _nativeTopic('wall_of_the_day_utc_p0530')]);

      messaging.unsubscribed.clear();
      await refreshWotdTopics(messaging, settings, offset: Duration.zero);
      expect(messaging.unsubscribed, isEmpty);
    });

    test('a failed leave of the global topic is retried on the next call', () async {
      messaging.failUnsubscribeFor.add('wall_of_the_day');
      await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 't', offset: ist);

      messaging
        ..unsubscribed.clear()
        ..failUnsubscribeFor.clear();
      await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 't', offset: ist);
      expect(messaging.unsubscribed, <String>[
        'wall_of_the_day_utc_p0530',
        'wall_of_the_day',
        _nativeTopic('wall_of_the_day'),
      ]);
    });

    test('turning it off retries earlier failed leaves and never leaves the bucket it just joined', () async {
      await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 't', offset: ist);
      messaging.failUnsubscribeFor.add('wall_of_the_day_utc_p0530');
      await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 't', offset: Duration.zero);
      messaging
        ..unsubscribed.clear()
        ..failUnsubscribeFor.clear();

      await setWotdTopics(messaging, settings, subscribed: false, sourceTag: 't', offset: Duration.zero);
      expect(
        messaging.unsubscribed,
        unorderedEquals(<String>[
          'wall_of_the_day_utc_p0530',
          _nativeTopic('wall_of_the_day_utc_p0530'),
          'wall_of_the_day',
          _nativeTopic('wall_of_the_day'),
          'wall_of_the_day_utc_p0000',
          _nativeTopic('wall_of_the_day_utc_p0000'),
        ]),
      );
    });

    test('rejoining a bucket drops it from the pending leaves', () async {
      await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 't', offset: ist);
      messaging.failUnsubscribeFor.add('wall_of_the_day_utc_p0530');
      await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 't', offset: Duration.zero);
      messaging.failUnsubscribeFor.clear();
      messaging.unsubscribed.clear();

      await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 't', offset: ist);
      expect(messaging.unsubscribed, isNot(contains(_nativeTopic('wall_of_the_day_utc_p0530'))));
    });

    test('refresh moves the device only when the offset changed and the push is on', () async {
      await refreshWotdTopics(messaging, settings, offset: ist);
      messaging
        ..subscribed.clear()
        ..unsubscribed.clear();

      await refreshWotdTopics(messaging, settings, offset: ist);
      expect(messaging.subscribed, isEmpty);

      await refreshWotdTopics(messaging, settings, offset: const Duration(hours: 1));
      expect(messaging.subscribed, <String>[_nativeTopic('wall_of_the_day_utc_p0100')]);
      expect(messaging.unsubscribed, contains('wall_of_the_day_utc_p0530'));

      await settings.set(PersistenceKeys.notifWotd, false);
      messaging.subscribed.clear();
      await refreshWotdTopics(messaging, settings, offset: ist);
      expect(messaging.subscribed, isEmpty);
    });
  });
}
