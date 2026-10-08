import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/notification_pref_keys.dart';
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
  final Set<Future<void>> _pendingWrites = <Future<void>>{};
  int _generation = 0;

  /// Fetches the current FCM token and writes it to Firestore for [userId].
  /// Call once after login.
  Future<void> syncToken({required String userId, FirebaseMessaging? messaging, FirestoreClient? client}) async {
    if (userId.trim().isEmpty) return;
    final int generation = _generation;
    try {
      final String? token = await (messaging ?? FirebaseMessaging.instance).getToken();
      if (generation != _generation || token == null || token.trim().isEmpty) return;
      await _trackWrite(() => _persistToken(userId: userId, token: token, client: client));
      if (generation != _generation) return;
      // Carries switches turned off before sign-in (or on an older build) over to the server.
      if (getIt.isRegistered<SettingsLocalDataSource>()) {
        final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
        if (!settings.get<bool>(NotificationPrefKeys.followers, defaultValue: true)) {
          await saveFollowerAlerts(userId: userId, enabled: false, client: client);
        }
        if (!settings.get<bool>(NotificationPrefKeys.recommendations, defaultValue: true)) {
          await saveMarketingPushes(userId: userId, enabled: false, client: client);
        }
      }
    } catch (e, st) {
      logger.w('FcmTokenService: failed to sync token.', error: e, stackTrace: st);
    }
  }

  /// Stores the Followers alert switch where onFollowCreated reads it.
  Future<void> saveFollowerAlerts({required String userId, required bool enabled, FirestoreClient? client}) async {
    if (userId.trim().isEmpty) return;
    try {
      await _trackWrite(
        () => (client ?? firestoreClient).setDoc(
          '${FirebaseCollections.usersV2}/$userId/private',
          'session',
          <String, dynamic>{'followerAlerts': enabled},
          merge: true,
          sourceTag: 'fcm_token.follower_alerts',
        ),
      );
    } catch (e, st) {
      logger.w('FcmTokenService: failed to save follower alerts.', error: e, stackTrace: st);
    }
  }

  /// Stores the Recommendations switch where the win-back and campaign pushes read it.
  Future<void> saveMarketingPushes({required String userId, required bool enabled, FirestoreClient? client}) async {
    if (userId.trim().isEmpty) return;
    try {
      await _trackWrite(
        () => (client ?? firestoreClient).setDoc(
          '${FirebaseCollections.usersV2}/$userId/private',
          'session',
          <String, dynamic>{'marketingPushes': enabled},
          merge: true,
          sourceTag: 'fcm_token.marketing_pushes',
        ),
      );
    } catch (e, st) {
      logger.w('FcmTokenService: failed to save marketing pushes.', error: e, stackTrace: st);
    }
  }

  /// Listens for token refreshes and persists the new token automatically.
  /// Call once after login.
  void listenForTokenRefresh({required String userId, FirebaseMessaging? messaging, FirestoreClient? client}) {
    _cancelListener();
    if (userId.trim().isEmpty) return;
    final int generation = _generation;
    _tokenRefreshSubscription = (messaging ?? FirebaseMessaging.instance).onTokenRefresh.listen((String newToken) {
      if (generation != _generation) return;
      unawaited(_persistRefreshedToken(userId, newToken, generation, client));
    });
  }

  void cancel() {
    _generation++;
    unawaited(_cancelListener());
  }

  /// Cancels future token writes and waits for writes already sent to Firestore.
  Future<void> cancelAndWait() async {
    _generation++;
    try {
      await _cancelListener();
    } catch (_) {}
    await Future.wait<void>(
      _pendingWrites
          .map((Future<void> write) async {
            try {
              await write;
            } catch (_) {}
          })
          .toList(growable: false),
    );
  }

  Future<void> _persistRefreshedToken(String userId, String token, int generation, FirestoreClient? client) async {
    if (generation != _generation) return;
    try {
      await _trackWrite(() => _persistToken(userId: userId, token: token, client: client));
    } catch (e, st) {
      logger.w('FcmTokenService: failed to persist refreshed token.', error: e, stackTrace: st);
    }
  }

  Future<void> _cancelListener() async {
    final Future<void>? cancellation = _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    await cancellation;
  }

  Future<void> _trackWrite(Future<void> Function() write) async {
    final Future<void> pending = Future<void>.sync(write);
    _pendingWrites.add(pending);
    try {
      await pending;
    } finally {
      _pendingWrites.remove(pending);
    }
  }

  Future<void> _persistToken({required String userId, required String token, FirestoreClient? client}) async {
    await (client ?? firestoreClient).setDoc(
      '${FirebaseCollections.usersV2}/$userId/private',
      'session',
      <String, dynamic>{'fcmToken': token},
      merge: true,
      sourceTag: 'fcm_token.sync',
    );
    logger.d('FcmTokenService: token synced for user $userId');
  }
}
