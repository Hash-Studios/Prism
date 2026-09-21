import 'dart:async';
import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/logger/logger.dart';
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

bool get creatorPostsAlertsEnabled => getIt<SettingsLocalDataSource>().get<bool>('postsSubscriber', defaultValue: true);

/// What the Posts switch controls: every followed creator's posts topic.
// ponytail: one topic call per followed creator, sequentially; batch server-side if follow lists get large.
Future<void> setCreatorPostsTopics(
  FirebaseMessaging messaging,
  Iterable<String> creatorEmails, {
  required bool subscribed,
  required String sourceTag,
}) async {
  for (final String email in creatorEmails) {
    final String? topic = _creatorPostsTopicFromEmail(email);
    if (topic == null) continue;
    if (subscribed) {
      await subscribeToTopicSafely(messaging, topic, sourceTag: sourceTag);
    } else {
      await unsubscribeFromTopicSafely(messaging, topic, sourceTag: sourceTag);
    }
  }
}

String? userTopicFromId(String uid) {
  final String sanitized = uid.trim().replaceAll(_invalidFcmTopicCharacters, '');
  return sanitized.isEmpty ? null : 'u_$sanitized';
}

Future<bool> subscribeToTopicSafely(FirebaseMessaging messaging, String topic, {required String sourceTag}) async {
  final String normalizedTopic = topic.trim();
  if (normalizedTopic.isEmpty) {
    return false;
  }
  try {
    final bool canProceed = await _canProceedWithTopicCall(messaging);
    if (!canProceed) {
      logger.w(
        'Skipping topic subscription until APNS token is available.',
        tag: 'Push',
        fields: <String, Object?>{'topic': normalizedTopic, 'sourceTag': sourceTag},
      );
      return false;
    }
    await messaging.subscribeToTopic(normalizedTopic);
    return true;
  } catch (error, stackTrace) {
    if (_isApnsTokenMissing(error)) {
      logger.w(
        'Topic subscription skipped because APNS token is not set yet.',
        tag: 'Push',
        error: error,
        stackTrace: stackTrace,
        fields: <String, Object?>{'topic': normalizedTopic, 'sourceTag': sourceTag},
      );
      return false;
    }
    logger.e(
      'Failed to subscribe to topic.',
      tag: 'Push',
      error: error,
      stackTrace: stackTrace,
      fields: <String, Object?>{'topic': normalizedTopic, 'sourceTag': sourceTag},
    );
    return false;
  }
}

Future<void> unsubscribeFromTopicSafely(FirebaseMessaging messaging, String topic, {required String sourceTag}) async {
  final String normalizedTopic = topic.trim();
  if (normalizedTopic.isEmpty) {
    return;
  }
  try {
    final bool canProceed = await _canProceedWithTopicCall(messaging);
    if (!canProceed) {
      logger.w(
        'Skipping topic unsubscription until APNS token is available.',
        tag: 'Push',
        fields: <String, Object?>{'topic': normalizedTopic, 'sourceTag': sourceTag},
      );
      return;
    }
    await messaging.unsubscribeFromTopic(normalizedTopic);
  } catch (error, stackTrace) {
    if (_isApnsTokenMissing(error)) {
      logger.w(
        'Topic unsubscription skipped because APNS token is not set yet.',
        tag: 'Push',
        error: error,
        stackTrace: stackTrace,
        fields: <String, Object?>{'topic': normalizedTopic, 'sourceTag': sourceTag},
      );
      return;
    }
    logger.e(
      'Failed to unsubscribe from topic.',
      tag: 'Push',
      error: error,
      stackTrace: stackTrace,
      fields: <String, Object?>{'topic': normalizedTopic, 'sourceTag': sourceTag},
    );
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
