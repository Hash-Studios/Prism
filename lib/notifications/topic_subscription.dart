import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
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

/// New-post pushes for a creator go to this topic (see onWallApproved). Older builds and older servers use it.
String? _creatorPostsTopicFromEmail(String email) {
  final String? base = followersTopicFromEmail(email);
  return base == null ? null : '${base}_posts';
}

/// The same pushes also go to `posts_<creator uid>` (see onWallApproved). Unlike the email prefix, a uid is unique.
String? creatorPostsTopicFromUid(String uid) {
  final String sanitized = uid.trim().replaceAll(_invalidFcmTopicCharacters, '');
  return sanitized.isEmpty ? null : 'posts_$sanitized';
}

bool get creatorPostsAlertsEnabled =>
    getIt<SettingsLocalDataSource>().get<bool>(NotificationPrefKeys.posts, defaultValue: true);

/// Returns the uid for a creator email, null when no such user exists, and throws when the read fails.
typedef CreatorUidResolver = Future<String?> Function(String email);

const String _creatorUidCacheKey = 'creatorUidByEmail';
const int _creatorUidResolveBatch = 10;

Future<String?> _resolveCreatorUidFromProfile(String email) async {
  final PublicProfileEntity? profile = await getIt<PublicProfileRepository>()
      .watchProfile(email)
      .first
      .timeout(const Duration(seconds: 8));
  return profile?.id;
}

Map<String, String> _readCreatorUidCache(SettingsLocalDataSource? settings) {
  if (settings == null) return <String, String>{};
  try {
    final Object? decoded = jsonDecode(settings.get<String>(_creatorUidCacheKey, defaultValue: '{}'));
    if (decoded is Map<String, dynamic>) {
      return decoded.map((String email, dynamic uid) => MapEntry<String, String>(email, uid.toString()));
    }
  } on FormatException {
    // A broken cache is rebuilt from the next reads.
  }
  return <String, String>{};
}

/// Follows store creator emails only. The uid of each creator comes from [knownUids], then from the local cache, then
/// from one profile read. Every uid that a read finds is cached, so each creator costs at most one read.
Future<({Map<String, String> uids, bool complete})> _creatorUids(
  Iterable<String> emails, {
  required Map<String, String> knownUids,
  required SettingsLocalDataSource? settings,
  required CreatorUidResolver? resolver,
}) async {
  final Map<String, String> cache = _readCreatorUidCache(settings)..addAll(knownUids);
  final Map<String, String> uids = <String, String>{};
  final List<String> missing = <String>[];
  for (final String email in emails) {
    final String uid = cache[email] ?? '';
    if (uid.isEmpty) {
      missing.add(email);
    } else {
      uids[email] = uid;
    }
  }
  bool complete = true;
  final CreatorUidResolver? resolve =
      resolver ?? (getIt.isRegistered<PublicProfileRepository>() ? _resolveCreatorUidFromProfile : null);
  if (resolve != null) {
    for (int start = 0; start < missing.length; start += _creatorUidResolveBatch) {
      final List<String> batch = missing.skip(start).take(_creatorUidResolveBatch).toList();
      await Future.wait(
        batch.map((String email) async {
          try {
            final String? uid = await resolve(email);
            if (uid != null && uid.isNotEmpty) uids[email] = uid;
          } catch (error, stackTrace) {
            complete = false;
            logger.w(
              'Could not resolve a creator uid for the posts topic.',
              tag: 'Push',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }),
      );
    }
  }
  final Map<String, String> learned = <String, String>{
    for (final MapEntry<String, String> entry in uids.entries)
      if (cache[entry.key] != entry.value) entry.key: entry.value,
  };
  if (settings != null && learned.isNotEmpty) {
    await settings.set(_creatorUidCacheKey, jsonEncode(<String, String>{...cache, ...learned}));
  }
  return (uids: uids, complete: complete);
}

/// Subscribes to or leaves the posts topics of [creatorEmails]: the legacy `<local>_posts` topic and `posts_<uid>`.
/// Returns false when a topic call or a uid read failed. Pass [knownUids] (email to uid) when the caller has them.
Future<bool> _changeCreatorPostsTopics(
  FirebaseMessaging messaging,
  Iterable<String> creatorEmails, {
  required bool subscribed,
  required String sourceTag,
  Map<String, String> knownUids = const <String, String>{},
  SettingsLocalDataSource? settings,
  CreatorUidResolver? resolver,
}) async {
  final Map<String, String> emailByKey = <String, String>{
    for (final String email in creatorEmails)
      if (email.trim().isNotEmpty) email.trim().toLowerCase(): email.trim(),
  };
  final SettingsLocalDataSource? store =
      settings ?? (getIt.isRegistered<SettingsLocalDataSource>() ? getIt<SettingsLocalDataSource>() : null);
  Future<bool> change(String? topic) => topic == null
      ? Future<bool>.value(true)
      : _changeTopic(messaging, topic, subscribe: subscribed, sourceTag: sourceTag);
  final List<bool> results = await Future.wait(<Future<bool>>[
    ...emailByKey.values.map((String email) => change(_creatorPostsTopicFromEmail(email))),
    _creatorUids(
      emailByKey.keys,
      knownUids: <String, String>{
        for (final MapEntry<String, String> entry in knownUids.entries) entry.key.trim().toLowerCase(): entry.value,
      },
      settings: store,
      resolver: resolver,
    ).then((({Map<String, String> uids, bool complete}) found) async {
      final List<bool> changed = await Future.wait(
        found.uids.values.map((String uid) => change(creatorPostsTopicFromUid(uid))),
      );
      return found.complete && changed.every((bool ok) => ok);
    }),
  ]);
  return results.every((bool ok) => ok);
}

/// What the Posts switch controls: every followed creator's posts topics.
Future<void> setCreatorPostsTopics(
  FirebaseMessaging messaging,
  Iterable<String> creatorEmails, {
  required bool subscribed,
  required String sourceTag,
  Map<String, String> knownUids = const <String, String>{},
}) async {
  await _changeCreatorPostsTopics(
    messaging,
    creatorEmails,
    subscribed: subscribed,
    sourceTag: sourceTag,
    knownUids: knownUids,
  );
}

String? userTopicFromId(String uid) {
  final String sanitized = uid.trim().replaceAll(_invalidFcmTopicCharacters, '');
  return sanitized.isEmpty ? null : 'u_$sanitized';
}

const String _pushTopicsSyncedKey = 'pushTopicsSyncedFor';
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
      _changeCreatorPostsTopics(messaging, following, subscribed: true, sourceTag: sourceTag, settings: settings),
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
