import 'dart:async';
import 'dart:io';

import 'package:Prism/logger/logger.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> subscribeToTopicSafely(FirebaseMessaging messaging, String topic, {required String sourceTag}) async {
  final String normalizedTopic = topic.trim();
  if (normalizedTopic.isEmpty) {
    return;
  }
  try {
    await messaging.requestPermission();
    final bool canProceed = await _canProceedWithTopicCall(messaging);
    if (!canProceed) {
      logger.w(
        'Skipping topic subscription until APNS token is available.',
        tag: 'Push',
        fields: <String, Object?>{'topic': normalizedTopic, 'sourceTag': sourceTag},
      );
      return;
    }
    await messaging.subscribeToTopic(normalizedTopic);
  } catch (error, stackTrace) {
    if (_isApnsTokenMissing(error)) {
      logger.w(
        'Topic subscription skipped because APNS token is not set yet.',
        tag: 'Push',
        error: error,
        stackTrace: stackTrace,
        fields: <String, Object?>{'topic': normalizedTopic, 'sourceTag': sourceTag},
      );
      return;
    }
    logger.e(
      'Failed to subscribe to topic.',
      tag: 'Push',
      error: error,
      stackTrace: stackTrace,
      fields: <String, Object?>{'topic': normalizedTopic, 'sourceTag': sourceTag},
    );
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
