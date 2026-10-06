import 'dart:async';
import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/notification_pref_keys.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final RegExp _invalidFcmTopicCharacters = RegExp(r'[^A-Za-z0-9\-_.~%]');

String? followersTopicFromEmail(String email) {
  final String localPart = email.trim().split('@').first.trim();
  if (localPart.isEmpty) {
    return null;
  }
  final String sanitizedLocalPart = localPart.replaceAll(_invalidFcmTopicCharacters, '');
  if (sanitizedLocalPart.isEmpty) {
    return null;
  }
  return sanitizedLocalPart;
}

/// New-post pushes for a creator go to this topic (see onWallApproved).
String? _creatorPostsTopicFromEmail(String email) {
  final String? base = followersTopicFromEmail(email);
  return base == null ? null : '${base}_posts';
}

bool get creatorPostsAlertsEnabled =>
    getIt<SettingsLocalDataSource>().get<bool>(NotificationPrefKeys.posts, defaultValue: true);

/// What the Posts switch controls: every followed creator's posts topic.
Future<void> setCreatorPostsTopics(
  FirebaseMessaging messaging,
  Iterable<String> creatorEmails, {
  required bool subscribed,
  required String sourceTag,
}) async {
  await Future.wait<void>(
    creatorEmails.map((String email) async {
      final String? topic = _creatorPostsTopicFromEmail(email);
      if (topic == null) return;
      if (subscribed) {
        await subscribeToTopicSafely(messaging, topic, sourceTag: sourceTag);
      } else {
        await unsubscribeFromTopicSafely(messaging, topic, sourceTag: sourceTag);
      }
    }),
  );
}

String? userTopicFromId(String uid) {
  final String sanitized = uid.trim().replaceAll(_invalidFcmTopicCharacters, '');
  return sanitized.isEmpty ? null : 'u_$sanitized';
}

const String _pushTopicsSyncedKey = 'pushTopicsSyncedFor';
const String _legacyWotdTopic = 'wall_of_the_day';
const String _wotdBucketKey = 'wotdBucketTopic';

/// Topic for the devices at [offset] from UTC, for example `wall_of_the_day_utc_p0530`. FCM topic names cannot hold `+`, so `p` marks east of UTC and `m` marks west.
/// The server sends the Wall of the Day push to the bucket where it is 09:00 local, in 15 minute steps.
String wotdBucketTopic([Duration? offset]) {
  final int minutes = (((offset ?? DateTime.now().timeZoneOffset).inMinutes) / 15).round() * 15;
  final int clamped = minutes.clamp(-720, 840);
  final int abs = clamped.abs();
  final String hh = (abs ~/ 60).toString().padLeft(2, '0');
  final String mm = (abs % 60).toString().padLeft(2, '0');
  return 'wall_of_the_day_utc_${clamped < 0 ? 'm' : 'p'}$hh$mm';
}

/// Turns the Wall of the Day push on or off. On, the device joins its time zone bucket and leaves the global
/// topic that older builds used, so it gets one push at 09:00 local. Call this instead of changing
/// `wall_of_the_day` directly.
Future<bool> setWotdTopics(
  FirebaseMessaging messaging,
  SettingsLocalDataSource settings, {
  required bool subscribed,
  required String sourceTag,
  Duration? offset,
}) async {
  final String storedBucket = settings.get<String>(_wotdBucketKey, defaultValue: '');
  if (!subscribed) {
    final List<bool> results = await Future.wait(<Future<bool>>[
      _changeTopic(messaging, _legacyWotdTopic, subscribe: false, sourceTag: sourceTag),
      _changeTopic(
        messaging,
        storedBucket.isEmpty ? wotdBucketTopic(offset) : storedBucket,
        subscribe: false,
        sourceTag: sourceTag,
      ),
    ]);
    final bool done = results.every((bool ok) => ok);
    if (done) await settings.set(_wotdBucketKey, '');
    return done;
  }
  final String bucket = wotdBucketTopic(offset);
  final bool joined = await subscribeToTopicSafely(messaging, bucket, sourceTag: sourceTag);
  if (!joined) return false;
  await _changeTopic(messaging, _legacyWotdTopic, subscribe: false, sourceTag: sourceTag);
  if (storedBucket.isNotEmpty && storedBucket != bucket) {
    await _changeTopic(messaging, storedBucket, subscribe: false, sourceTag: sourceTag);
  }
  await settings.set(_wotdBucketKey, bucket);
  return true;
}

/// Moves the device to its current time zone bucket when the offset changed (travel, daylight saving) and also
/// moves installs that still use the global topic. Does nothing when the Wall of the Day push is off.
Future<void> refreshWotdTopics(
  FirebaseMessaging messaging,
  SettingsLocalDataSource settings, {
  Duration? offset,
}) async {
  if (!settings.get<bool>(PersistenceKeys.notifWotd, defaultValue: true)) return;
  if (settings.get<String>(_wotdBucketKey, defaultValue: '') == wotdBucketTopic(offset)) return;
  await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 'push_topics.wotd_refresh', offset: offset);
}

/// Subscribes this device to every topic the server sends to, once per FCM token, user and tier.
/// Topics belong to the token. iOS builds without the push entitlement never had one, so
/// every earlier subscribe was skipped. This catches up those installs and fresh tokens.
Future<void> syncPushTopics(
  FirebaseMessaging messaging,
  SettingsLocalDataSource settings, {
  required String userId,
  required String email,
  required bool premium,
  required Iterable<String> following,
}) async {
  final String? token;
  try {
    token = await messaging.getToken();
  } catch (error, stackTrace) {
    logger.w('Topic sync skipped: no FCM token yet.', tag: 'Push', error: error, stackTrace: stackTrace);
    return;
  }
  if (token == null || token.isEmpty) return;
  final String tier = premium ? 'premium' : 'free';
  final String syncKey = '$token|$userId|$tier';
  if (settings.get<String>(_pushTopicsSyncedKey, defaultValue: '') == syncKey) return;

  const String sourceTag = 'push_topics.sync';
  Future<bool> subscribe(String? topic) =>
      topic == null ? Future<bool>.value(true) : subscribeToTopicSafely(messaging, topic, sourceTag: sourceTag);
  final List<bool> results = await Future.wait(<Future<bool>>[
    if (settings.get<bool>(NotificationPrefKeys.recommendations, defaultValue: true)) subscribe('recommendations'),
    if (settings.get<bool>(PersistenceKeys.notifWotd, defaultValue: true))
      setWotdTopics(messaging, settings, subscribed: true, sourceTag: sourceTag),
    // onCampaignNotificationRequested sends "premium" and "free" campaigns to these topics.
    subscribe(tier),
    _changeTopic(messaging, premium ? 'free' : 'premium', subscribe: false, sourceTag: sourceTag),
    if (userId.isNotEmpty) ...<Future<bool>>[
      subscribe(userTopicFromId(userId)),
      subscribe(followersTopicFromEmail(email)),
    ],
    if (userId.isNotEmpty && settings.get<bool>(NotificationPrefKeys.posts, defaultValue: true))
      ...following.map((String creator) => subscribe(_creatorPostsTopicFromEmail(creator))),
  ]);
  if (results.every((bool ok) => ok)) await settings.set(_pushTopicsSyncedKey, syncKey);
}

Future<bool> subscribeToTopicSafely(FirebaseMessaging messaging, String topic, {required String sourceTag}) {
  return _changeTopic(messaging, topic, subscribe: true, sourceTag: sourceTag);
}

Future<void> unsubscribeFromTopicSafely(FirebaseMessaging messaging, String topic, {required String sourceTag}) {
  return _changeTopic(messaging, topic, subscribe: false, sourceTag: sourceTag);
}

/// Subscribes to or unsubscribes from [topic]; returns whether the call went through.
Future<bool> _changeTopic(
  FirebaseMessaging messaging,
  String topic, {
  required bool subscribe,
  required String sourceTag,
}) async {
  final String normalizedTopic = topic.trim();
  if (normalizedTopic.isEmpty) {
    return false;
  }
  final String noun = subscribe ? 'subscription' : 'unsubscription';
  final Map<String, Object?> fields = <String, Object?>{'topic': normalizedTopic, 'sourceTag': sourceTag};
  try {
    final bool canProceed = await _canProceedWithTopicCall(messaging);
    if (!canProceed) {
      logger.w('Skipping topic $noun until APNS token is available.', tag: 'Push', fields: fields);
      return false;
    }
    if (subscribe) {
      await messaging.subscribeToTopic(normalizedTopic);
    } else {
      await messaging.unsubscribeFromTopic(normalizedTopic);
    }
    return true;
  } catch (error, stackTrace) {
    if (_isApnsTokenMissing(error)) {
      logger.w(
        'Topic $noun skipped because APNS token is not set yet.',
        tag: 'Push',
        error: error,
        stackTrace: stackTrace,
        fields: fields,
      );
      return false;
    }
    logger.e(
      'Failed to ${subscribe ? 'subscribe to' : 'unsubscribe from'} topic.',
      tag: 'Push',
      error: error,
      stackTrace: stackTrace,
      fields: fields,
    );
    return false;
  }
}

Future<bool> _canProceedWithTopicCall(FirebaseMessaging messaging) async {
  if (!(Platform.isIOS || Platform.isMacOS)) {
    return true;
  }
  for (int attempt = 0; attempt < 3; attempt++) {
    final String? token = await messaging.getAPNSToken();
    if (token != null && token.trim().isNotEmpty) {
      return true;
    }
    await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
  }
  return false;
}

bool _isApnsTokenMissing(Object error) {
  return error.toString().contains('apns-token-not-set');
}
