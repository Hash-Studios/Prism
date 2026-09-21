import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/logger/logger.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Stores and keeps the FCM device token up-to-date in the user's Firestore
/// private session document (`usersv2/{userId}/private/session`).
///
/// Cloud Functions use this token to send direct push notifications to a
/// specific user (e.g. follower notifications when the user isn't subscribed
/// to any relevant topic).
class FcmTokenService {
  FcmTokenService._();
  static final FcmTokenService instance = FcmTokenService._();
  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Fetches the current FCM token and writes it to Firestore for [userId].
  /// Call once after login.
  Future<void> syncToken({required String userId}) async {
    if (userId.trim().isEmpty) return;
    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;
      await _persistToken(userId: userId, token: token);
      // Carries a Followers switch turned off on an older build over to the server.
      if (getIt.isRegistered<SettingsLocalDataSource>() &&
          !getIt<SettingsLocalDataSource>().get<bool>('followersSubscriber', defaultValue: true)) {
        await saveFollowerAlerts(userId: userId, enabled: false);
      }
    } catch (e, st) {
      logger.w('FcmTokenService: failed to sync token.', error: e, stackTrace: st);
    }
  }

  /// Stores the Followers alert switch where onFollowCreated reads it.
  Future<void> saveFollowerAlerts({required String userId, required bool enabled, FirestoreClient? client}) async {
    if (userId.trim().isEmpty) return;
    try {
      await (client ?? firestoreClient).setDoc(
        '${FirebaseCollections.usersV2}/$userId/private',
        'session',
        <String, dynamic>{'followerAlerts': enabled},
        merge: true,
        sourceTag: 'fcm_token.follower_alerts',
      );
    } catch (e, st) {
      logger.w('FcmTokenService: failed to save follower alerts.', error: e, stackTrace: st);
    }
  }

  /// Listens for token refreshes and persists the new token automatically.
  /// Call once after login.  Returns a cancel function.
  void Function() listenForTokenRefresh({required String userId}) {
    cancel();
    if (userId.trim().isEmpty) return cancel;
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
      try {
        await _persistToken(userId: userId, token: newToken);
      } catch (e, st) {
        logger.w('FcmTokenService: failed to persist refreshed token.', error: e, stackTrace: st);
      }
    });
    return cancel;
  }

  void cancel() {
    final subscription = _tokenRefreshSubscription;
    _tokenRefreshSubscription = null;
    unawaited(subscription?.cancel());
  }

  Future<void> _persistToken({required String userId, required String token}) async {
    await firestoreClient.setDoc(
      '${FirebaseCollections.usersV2}/$userId/private',
      'session',
      <String, dynamic>{'fcmToken': token},
      merge: true,
      sourceTag: 'fcm_token.sync',
    );
    logger.d('FcmTokenService: token synced for user $userId');
  }
}
