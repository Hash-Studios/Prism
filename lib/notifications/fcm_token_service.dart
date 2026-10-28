import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/firestore/firestore_sentinels.dart';
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
  bool _tokenInvalidationPending = false;
  Future<void>? _tokenInvalidation;
  Future<void>? _signOutBarrier;
  String? _boundUserId;
  String? _activeSyncUserId;
  static const String _syncedTokenKey = 'fcmTokenSynced';
  static const String _tokenRotationKey = 'fcmTokenRotationV2';
  static const String _tokenInvalidationPendingKey = 'fcmTokenInvalidationPendingV1';

  /// Fetches the current FCM token and writes it to Firestore for [userId].
  /// Call once after login.
  Future<void> syncToken({required String userId, FirebaseMessaging? messaging, FirestoreClient? client}) async {
    if (userId.trim().isEmpty) return;
    if (_activeSyncUserId != null && _activeSyncUserId != userId) {
      final int switchGeneration = ++_generation;
      _activeSyncUserId = userId;
      _boundUserId = null;
      await _cancelListener();
      await _waitForPendingWrites();
      if (switchGeneration != _generation) return;
    } else {
      _activeSyncUserId = userId;
    }
    final int generation = _generation;
    try {
      final Future<void>? signOutBarrier = _signOutBarrier;
      if (signOutBarrier != null) await signOutBarrier;
      if (generation != _generation) return;
      final FirebaseMessaging resolvedMessaging = messaging ?? FirebaseMessaging.instance;
      final Future<void>? invalidation = _tokenInvalidation;
      if (invalidation != null) await invalidation;
      if (generation != _generation) return;
      final SettingsLocalDataSource? settings = getIt.isRegistered<SettingsLocalDataSource>()
          ? getIt<SettingsLocalDataSource>()
          : null;
      final String rotatedFor = settings?.isOpen == true
          ? settings!.get<String>(_tokenRotationKey, defaultValue: '')
          : '';
      final bool pendingInvalidation =
          settings?.isOpen == true && settings!.get<bool>(_tokenInvalidationPendingKey, defaultValue: false);
      if (_tokenInvalidationPending || pendingInvalidation || (invalidation == null && rotatedFor != userId)) {
        await _invalidateToken(resolvedMessaging, rotatedForUser: userId, client: client);
        if (generation != _generation) return;
      } else if (invalidation != null && settings?.isOpen == true) {
        await settings!.set(_tokenRotationKey, userId);
      }
      final String? token = await resolvedMessaging.getToken();
      if (generation != _generation || token == null || token.trim().isEmpty) return;
      await _trackWrite(() => _persistToken(userId: userId, token: token, client: client));
      if (generation != _generation) return;
      _boundUserId = userId;
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

  /// Stores the Posts switch where the follow digest reads it.
  Future<void> savePostAlerts({required String userId, required bool enabled, FirestoreClient? client}) async {
    if (userId.trim().isEmpty) return;
    try {
      await _trackWrite(
        () => (client ?? firestoreClient).setDoc(
          '${FirebaseCollections.usersV2}/$userId/private',
          'session',
          <String, dynamic>{'postAlerts': enabled},
          merge: true,
          sourceTag: 'fcm_token.post_alerts',
        ),
      );
    } catch (e, st) {
      logger.w('FcmTokenService: failed to save post alerts.', error: e, stackTrace: st);
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
      if (generation != _generation || _tokenInvalidationPending) return;
      if (_boundUserId != userId) {
        unawaited(syncToken(userId: userId, messaging: messaging, client: client));
      } else {
        unawaited(_persistRefreshedToken(userId, newToken, generation, client));
      }
    });
  }

  void cancel() {
    _generation++;
    unawaited(_cancelListener());
  }

  /// Cancels future token writes and waits for writes already sent to Firestore.
  Future<void> cancelAndWait() async {
    _generation++;
    _activeSyncUserId = null;
    _boundUserId = null;
    try {
      await _cancelListener();
    } catch (_) {}
    await _waitForPendingWrites();
  }

  Future<void> _waitForPendingWrites() async {
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

  /// Invalidates the device token on sign-out so the old user's stored token cannot receive private pushes here.
  /// If invalidation fails, future token syncs retry it and do not bind the old token to another user.
  Future<void> invalidateTokenForSignOut({
    String userId = '',
    FirebaseMessaging? messaging,
    FirestoreClient? client,
  }) async {
    _boundUserId = null;
    _activeSyncUserId = null;
    _tokenInvalidationPending = true;
    final Completer<void> barrier = Completer<void>();
    _signOutBarrier = barrier.future;
    try {
      await _invalidateToken(messaging ?? FirebaseMessaging.instance, clearForUser: userId, client: client);
    } finally {
      barrier.complete();
      if (identical(_signOutBarrier, barrier.future)) _signOutBarrier = null;
    }
  }

  Future<void> _invalidateToken(
    FirebaseMessaging messaging, {
    String? rotatedForUser,
    String? clearForUser,
    FirestoreClient? client,
  }) async {
    final Future<void>? existing = _tokenInvalidation;
    if (existing != null) {
      try {
        await existing;
      } catch (error, stackTrace) {
        if (clearForUser != null && clearForUser.trim().isNotEmpty) {
          await _clearStoredTokenBestEffort(clearForUser, client: client);
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
      if (clearForUser != null && clearForUser.trim().isNotEmpty) {
        await _invalidateToken(messaging, clearForUser: clearForUser, client: client);
      }
      return;
    }
    _tokenInvalidationPending = true;
    late final Future<void> invalidation;
    invalidation = () async {
      if (getIt.isRegistered<SettingsLocalDataSource>()) {
        final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
        if (settings.isOpen) await settings.set(_tokenInvalidationPendingKey, true);
      }
      try {
        await messaging.deleteToken();
      } catch (error, stackTrace) {
        if (clearForUser != null && clearForUser.trim().isNotEmpty) {
          await _clearStoredTokenBestEffort(clearForUser, client: client);
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
      if (clearForUser != null && clearForUser.trim().isNotEmpty) {
        await _clearStoredTokenBestEffort(clearForUser, client: client);
      }
      await clearSyncedToken();
      if (getIt.isRegistered<SettingsLocalDataSource>()) {
        final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
        if (settings.isOpen) {
          await settings.delete(_tokenRotationKey);
          await settings.delete(_tokenInvalidationPendingKey);
        }
      }
      if (rotatedForUser != null && getIt.isRegistered<SettingsLocalDataSource>()) {
        final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
        if (settings.isOpen) await settings.set(_tokenRotationKey, rotatedForUser);
      }
      _tokenInvalidationPending = false;
    }();
    _tokenInvalidation = invalidation;
    try {
      await invalidation;
    } finally {
      if (identical(_tokenInvalidation, invalidation)) _tokenInvalidation = null;
    }
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

  /// Forgets the last synced token so the next sign-in writes it again.
  Future<void> clearSyncedToken() async {
    if (!getIt.isRegistered<SettingsLocalDataSource>()) return;
    final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
    if (settings.isOpen) await settings.delete(_syncedTokenKey);
  }

  Future<void> _persistToken({required String userId, required String token, FirestoreClient? client}) async {
    final SettingsLocalDataSource? settings = getIt.isRegistered<SettingsLocalDataSource>()
        ? getIt<SettingsLocalDataSource>()
        : null;
    final bool postAlerts =
        settings?.isOpen != true ||
        settings!.get<bool>(NotificationPrefKeys.posts, defaultValue: true) &&
            settings.get<bool>(NotificationPrefKeys.followers, defaultValue: true);
    final String marker = '$userId|$token|digest_v2|posts:$postAlerts';
    final bool track = settings != null && settings.isOpen;
    if (track && settings.get<String>(_syncedTokenKey, defaultValue: '') == marker) return;
    await (client ?? firestoreClient).setDoc(
      '${FirebaseCollections.usersV2}/$userId/private',
      'session',
      <String, dynamic>{
        'fcmToken': token,
        'notificationLocalizationVersion': 2,
        'notificationLocalizationToken': token,
        'fcmTokenBindingVersion': 1,
        'fcmTokenBindingToken': token,
        // This build gets the daily follow digest in place of the per-upload topic pushes. The token marks the device,
        // so an older build that rebinds the account keeps its topic pushes.
        'postAlerts': postAlerts,
        'postAlertsToken': token,
      },
      merge: true,
      sourceTag: 'fcm_token.sync',
    );
    if (track) await settings.set(_syncedTokenKey, marker);
    logger.d('FcmTokenService: token synced for user $userId');
  }

  Future<void> _clearStoredToken(String userId, {FirestoreClient? client}) async {
    await (client ?? firestoreClient).setDoc(
      '${FirebaseCollections.usersV2}/$userId/private',
      'session',
      <String, dynamic>{
        'fcmToken': FirestoreSentinels.delete(),
        'notificationLocalizationVersion': FirestoreSentinels.delete(),
        'notificationLocalizationToken': FirestoreSentinels.delete(),
        'fcmTokenBindingVersion': FirestoreSentinels.delete(),
        'fcmTokenBindingToken': FirestoreSentinels.delete(),
      },
      merge: true,
      sourceTag: 'fcm_token.clear_on_signout',
    );
  }

  Future<void> _clearStoredTokenBestEffort(String userId, {FirestoreClient? client}) async {
    try {
      await _clearStoredToken(userId, client: client);
    } catch (error, stackTrace) {
      logger.w('FcmTokenService: failed to clear the old token binding.', error: error, stackTrace: stackTrace);
    }
  }
}
