import 'dart:async';
import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
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

/// The same pushes also go to `posts_<creator uid>` (see onWallApproved). Unlike the email prefix, a uid is unique.
String? creatorPostsTopicFromUid(String uid) {
  final String value = uid.trim();
  if (value.isEmpty || value.contains('@')) return null;
  final String sanitized = value.replaceAll(_invalidFcmTopicCharacters, '');
  return sanitized.isEmpty ? null : 'posts_$sanitized';
}

Future<bool> setCreatorPostsTopicForUid(
  FirebaseMessaging messaging,
  String uid, {
  required bool subscribed,
  required String sourceTag,
  bool Function()? isCurrent,
}) async {
  final String? topic = creatorPostsTopicFromUid(uid);
  if (topic == null) return false;
  return _changeTopic(messaging, topic, subscribe: subscribed, sourceTag: sourceTag, isCurrent: isCurrent);
}

/// Subscribes to or leaves the posts topics for creator UIDs. [isCurrent] stops after ownership changes.
Future<bool> _changeCreatorPostsTopics(
  FirebaseMessaging messaging,
  Iterable<String> creatorUids, {
  required bool subscribed,
  required String sourceTag,
  bool Function()? isCurrent,
}) async {
  if (!(isCurrent?.call() ?? true)) return false;
  final Set<String> uids = creatorUids
      .map((String uid) => uid.trim())
      .where((uid) => uid.isNotEmpty && !uid.contains('@'))
      .toSet();
  Future<bool> change(String? topic) => topic == null
      ? Future<bool>.value(true)
      : _changeTopic(messaging, topic, subscribe: subscribed, sourceTag: sourceTag, isCurrent: isCurrent);
  final List<bool> results = await Future.wait(<Future<bool>>[
    for (final String uid in uids) change(creatorPostsTopicFromUid(uid)),
  ]);
  return results.every((bool ok) => ok);
}

Future<bool> syncCreatorPostsTopicsForUser(
  FirebaseMessaging messaging, {
  required String userId,
  required bool subscribed,
  required String sourceTag,
  bool Function()? isCurrent,
}) async {
  final String ownerUid = userId.trim();
  if (ownerUid.isEmpty || !(isCurrent?.call() ?? true)) return false;
  try {
    final List<String> followingUids = await firestoreClient.query<String>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.profileFollowing(ownerUid),
        sourceTag: 'push_topics.following_uids',
      ),
      (_, docId) => docId,
    );
    if (!(isCurrent?.call() ?? true)) return false;
    return await _changeCreatorPostsTopics(
      messaging,
      followingUids,
      subscribed: subscribed,
      sourceTag: sourceTag,
      isCurrent: isCurrent,
    );
  } catch (error, stackTrace) {
    logger.w(
      'Could not load followed creator UIDs for posts topics.',
      tag: 'Push',
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  }
}

String? userTopicFromId(String uid) {
  final String sanitized = uid.trim().replaceAll(_invalidFcmTopicCharacters, '');
  return sanitized.isEmpty ? null : 'u_$sanitized';
}

const String _pushTopicsSyncedKey = 'pushTopicsSyncedForLocV2';
const String _creatorPostsMigrationKey = 'creatorPostsUidMigrationV2';
const String _nativeLocalizationTopicSuffix = '_loc_v1';
const String _legacyWotdTopic = 'wall_of_the_day';
const String _wotdBucketKey = 'wotdBucketTopic';
const String _wotdPendingCleanupKey = 'wotdPendingCleanupTopics';

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
    final String bucketToLeave = storedBucket.isEmpty ? wotdBucketTopic(offset) : storedBucket;
    final bool done = await _cleanupWotdTopics(messaging, settings, <String>[
      _legacyWotdTopic,
      bucketToLeave,
    ], sourceTag: sourceTag);
    if (done) await settings.set(_wotdBucketKey, '');
    return done;
  }
  final String bucket = wotdBucketTopic(offset);
  final bool joined = await subscribeToTopicSafely(messaging, bucket, sourceTag: sourceTag);
  if (!joined) return false;
  await _cleanupWotdTopics(
    messaging,
    settings,
    <String>[_legacyWotdTopic, if (storedBucket.isNotEmpty) storedBucket],
    keep: bucket,
    sourceTag: sourceTag,
  );
  await settings.set(_wotdBucketKey, bucket);
  return true;
}

Set<String> _pendingWotdCleanup(SettingsLocalDataSource settings) => settings
    .get<String>(_wotdPendingCleanupKey, defaultValue: '')
    .split(',')
    .where((String topic) => topic.isNotEmpty)
    .toSet();

/// Unsubscribes from [topics] plus every topic an earlier call could not leave, and keeps the ones that still fail
/// so the next refresh or toggle retries them. Never leaves [keep], the bucket the device just joined.
Future<bool> _cleanupWotdTopics(
  FirebaseMessaging messaging,
  SettingsLocalDataSource settings,
  Iterable<String> topics, {
  required String sourceTag,
  String keep = '',
}) async {
  final List<String> targets = <String>{
    ..._pendingWotdCleanup(settings),
    ...topics,
  }.where((String topic) => topic.isNotEmpty && topic != keep).toList();
  final List<bool> results = await Future.wait(
    targets.map((String topic) => _changeTopic(messaging, topic, subscribe: false, sourceTag: sourceTag)),
  );
  final List<String> failed = <String>[
    for (int i = 0; i < targets.length; i++)
      if (!results[i]) targets[i],
  ];
  await settings.set(_wotdPendingCleanupKey, failed.join(','));
  return failed.isEmpty;
}

/// Moves the device to its current time zone bucket when the offset changed (travel, daylight saving) and also
/// moves installs that still use the global topic. It also retries unsubscribes that failed before. Does not join
/// anything when the Wall of the Day push is off.
Future<void> refreshWotdTopics(
  FirebaseMessaging messaging,
  SettingsLocalDataSource settings, {
  Duration? offset,
}) async {
  if (_pendingWotdCleanup(settings).isNotEmpty) {
    await _cleanupWotdTopics(messaging, settings, const <String>[], sourceTag: 'push_topics.wotd_refresh');
  }
  if (!settings.get<bool>(PersistenceKeys.notifWotd, defaultValue: true)) return;
  if (settings.get<String>(_wotdBucketKey, defaultValue: '') == wotdBucketTopic(offset)) return;
  await setWotdTopics(messaging, settings, subscribed: true, sourceTag: 'push_topics.wotd_refresh', offset: offset);
}

/// Subscribes this device to broadcast topics, once per FCM token, user and tier.
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
  const String sourceTag = 'push_topics.sync';
  final String migrationKey = '$token|$userId|uid_v2';
  bool migratedCreatorTopics = settings.get<String>(_creatorPostsMigrationKey, defaultValue: '') == migrationKey;
  if (!migratedCreatorTopics) {
    final bool cleaned = await unsubscribeLegacyCreatorPostsTopics(
      messaging,
      following,
      sourceTag: '$sourceTag.creator_uid_migration',
    );
    if (cleaned) {
      await settings.set(_creatorPostsMigrationKey, migrationKey);
      migratedCreatorTopics = true;
    }
  }
  final String tier = premium ? 'premium' : 'free';
  final String syncKey = '$token|$userId|$tier|digest_v1';
  if (settings.get<String>(_pushTopicsSyncedKey, defaultValue: '') == syncKey && migratedCreatorTopics) return;

  Future<bool> subscribe(String? topic) =>
      topic == null ? Future<bool>.value(true) : subscribeToTopicSafely(messaging, topic, sourceTag: sourceTag);
  final List<bool> results = await Future.wait(<Future<bool>>[
    migratedCreatorTopics ? Future<bool>.value(true) : Future<bool>.value(false),
    if (settings.get<bool>(NotificationPrefKeys.recommendations, defaultValue: true)) subscribe('recommendations'),
    if (settings.get<bool>(NotificationPrefKeys.drops, defaultValue: true)) subscribe('drops'),
    if (settings.get<bool>(PersistenceKeys.notifWotd, defaultValue: true))
      setWotdTopics(messaging, settings, subscribed: true, sourceTag: sourceTag),
    // onCampaignNotificationRequested sends "premium" and "free" campaigns to these topics.
    subscribe(tier),
    _changeTopic(messaging, premium ? 'free' : 'premium', subscribe: false, sourceTag: sourceTag),
    if (userId.isNotEmpty) ...<Future<bool>>[
      if (userTopicFromId(userId) case final String userTopic)
        _changeTopic(messaging, userTopic, subscribe: false, sourceTag: sourceTag),
      subscribe(followersTopicFromEmail(email)),
    ],
    // This build gets the follow digest by token, so it leaves the per-upload posts topics that older builds joined
    // while the Posts switch was on.
    if (userId.isNotEmpty && settings.get<bool>(NotificationPrefKeys.posts, defaultValue: true))
      syncCreatorPostsTopicsForUser(messaging, userId: userId, subscribed: false, sourceTag: sourceTag),
  ]);
  if (results.every((bool ok) => ok)) await settings.set(_pushTopicsSyncedKey, syncKey);
}

/// Removes email-derived creator topics left by older app versions. Email-only creator identifiers are never used
/// to subscribe to a topic; they are accepted here only to clean up that legacy subscription.
Future<bool> unsubscribeLegacyCreatorPostsTopics(
  FirebaseMessaging messaging,
  Iterable<String> legacyFollowing, {
  required String sourceTag,
  bool Function()? isCurrent,
}) async {
  final Set<String> topics = <String>{};
  for (final String identifier in legacyFollowing) {
    final String email = identifier.trim();
    if (!email.contains('@')) continue;
    final String? localPart = followersTopicFromEmail(email);
    if (localPart != null) topics.add('${localPart}_posts');
  }
  final List<bool> results = await Future.wait(<Future<bool>>[
    for (final String topic in topics)
      _changeTopic(messaging, topic, subscribe: false, sourceTag: sourceTag, isCurrent: isCurrent),
  ]);
  return results.every((bool result) => result);
}

Future<bool> subscribeToTopicSafely(
  FirebaseMessaging messaging,
  String topic, {
  required String sourceTag,
  bool Function()? isCurrent,
}) {
  return _changeTopic(messaging, topic, subscribe: true, sourceTag: sourceTag, isCurrent: isCurrent);
}

Future<void> unsubscribeFromTopicSafely(
  FirebaseMessaging messaging,
  String topic, {
  required String sourceTag,
  bool Function()? isCurrent,
}) {
  return _changeTopic(messaging, topic, subscribe: false, sourceTag: sourceTag, isCurrent: isCurrent);
}

/// Subscribes to or unsubscribes from [topic]; returns whether the call went through.
Future<bool> _changeTopic(
  FirebaseMessaging messaging,
  String topic, {
  required bool subscribe,
  required String sourceTag,
  bool Function()? isCurrent,
}) async {
  if (!(isCurrent?.call() ?? true)) return false;
  final String normalizedTopic = topic.trim();
  if (normalizedTopic.isEmpty) {
    return false;
  }
  final String legacyTopic = normalizedTopic.endsWith(_nativeLocalizationTopicSuffix)
      ? normalizedTopic.substring(0, normalizedTopic.length - _nativeLocalizationTopicSuffix.length)
      : normalizedTopic;
  final String localizationTopic = '$legacyTopic$_nativeLocalizationTopicSuffix';
  final String noun = subscribe ? 'subscription' : 'unsubscription';
  final Map<String, Object?> fields = <String, Object?>{
    'topic': subscribe ? localizationTopic : legacyTopic,
    'sourceTag': sourceTag,
  };
  try {
    final bool canProceed = await _canProceedWithTopicCall(messaging, isCurrent: isCurrent);
    if (!(isCurrent?.call() ?? true)) return false;
    if (!canProceed) {
      logger.w('Skipping topic $noun until APNS token is available.', tag: 'Push', fields: fields);
      return false;
    }
    if (subscribe) {
      await messaging.subscribeToTopic(localizationTopic);
      if (!(isCurrent?.call() ?? true)) return false;
      if (legacyTopic != localizationTopic) {
        await messaging.unsubscribeFromTopic(legacyTopic);
      }
    } else {
      await messaging.unsubscribeFromTopic(legacyTopic);
      if (!(isCurrent?.call() ?? true)) return false;
      if (legacyTopic != localizationTopic) {
        await messaging.unsubscribeFromTopic(localizationTopic);
      }
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

Future<bool> _canProceedWithTopicCall(FirebaseMessaging messaging, {bool Function()? isCurrent}) async {
  if (!(Platform.isIOS || Platform.isMacOS)) {
    return true;
  }
  for (int attempt = 0; attempt < 3; attempt++) {
    if (!(isCurrent?.call() ?? true)) return false;
    final String? token = await messaging.getAPNSToken();
    if (!(isCurrent?.call() ?? true)) return false;
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
