import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:firebase_messaging/firebase_messaging.dart';

/// Stores and keeps the FCM device token up-to-date in the user's Firestore
/// document (`usersv2/{userId}.fcmToken`).
///
/// Cloud Functions use this token to send direct push notifications to a
/// specific user (e.g. follower notifications when the user isn't subscribed
/// to any relevant topic).
class FcmTokenService {
  FcmTokenService._();
  static final FcmTokenService instance = FcmTokenService._();

  /// Fetches the current FCM token and writes it to Firestore for [userId].
  /// Call once after login.
  Future<void> syncToken({required String userId}) async {
    if (userId.trim().isEmpty) return;
    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;
      await _persistToken(userId: userId, token: token);
    } catch (e, st) {
      logger.w('FcmTokenService: failed to sync token.', error: e, stackTrace: st);
    }
  }

  /// Listens for token refreshes and persists the new token automatically.
  /// Call once after login.  Returns a cancel function.
  void listenForTokenRefresh({required String userId}) {
    if (userId.trim().isEmpty) return;
    FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
      try {
        await _persistToken(userId: userId, token: newToken);
      } catch (e, st) {
        logger.w('FcmTokenService: failed to persist refreshed token.', error: e, stackTrace: st);
      }
    });
  }

  Future<void> _persistToken({required String userId, required String token}) async {
    final bool streakReminderEnabled =
        !main.prefs.isOpen || ((main.prefs.get('streakReminderSubscriber', defaultValue: true) as bool?) ?? true);
    await firestoreClient.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
      'fcmToken': token,
      'coinState.streakTimezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      'coinState.streakReminderEnabled': streakReminderEnabled,
    }, sourceTag: 'fcm_token.sync');
    logger.d('FcmTokenService: token synced for user $userId');
  }
}
