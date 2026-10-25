import 'dart:async';

import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/platform/live_activity_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_live_activity_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Sends this device's review queue Live Activity tokens to the server, for admins on iOS. Never throws.
class ReviewLiveActivitySync implements PrismLiveActivityFlutterApi {
  ReviewLiveActivitySync._();
  static final ReviewLiveActivitySync instance = ReviewLiveActivitySync._();

  @visibleForTesting
  static Future<void> Function(Map<String, Object?> data) register = _callRegister;
  @visibleForTesting
  static bool Function() isAdmin = () => app_state.prismUser.loggedIn && app_state.isAdminUser();
  @visibleForTesting
  static String? Function() currentUserId = () => FirebaseAuth.instance.currentUser?.uid;
  @visibleForTesting
  static Duration retryDelay = const Duration(seconds: 1);

  String? _ownerId;
  final Map<String, String?> _sent = <String, String?>{};
  Future<void> _sendTail = Future<void>.value();
  int _generation = 0;

  /// Asks the native side for the latest tokens. Call it after the signed-in user is known; it is safe to call again.
  static Future<void> start() async {
    if (!LiveActivityChannel.isSupported || !_isCurrentAdmin(currentUserId())) return;
    _invalidateSession();
    PrismLiveActivityFlutterApi.setUp(instance);
    await LiveActivityChannel.startReviewTokenUpdates();
  }

  @override
  void onReviewPushToStartToken(String token) => unawaited(_send('pushToStartToken', token));

  @override
  void onReviewActivityToken(String? token) => unawaited(_send('activityToken', token));

  Future<void> _send(String key, String? value) async {
    try {
      final String? userId = currentUserId();
      if (userId == null || !_isCurrentAdmin(userId)) return;
      final int generation = instance._generation;
      final Future<void> send = _sendTail.then((_) => _sendForUser(userId, key, value, generation));
      _sendTail = send.catchError((Object error, StackTrace stackTrace) {
        logger.w('Review Live Activity token sync failed', tag: 'live_activity', error: error, stackTrace: stackTrace);
      });
      await _sendTail;
    } catch (error, stackTrace) {
      logger.w('Review Live Activity token sync failed', tag: 'live_activity', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _sendForUser(String userId, String key, String? value, int generation) async {
    if (_generation != generation || !_isCurrentAdmin(userId)) return;
    if (_ownerId != userId) {
      _ownerId = userId;
      _sent.clear();
    }
    if (_sent.containsKey(key) && _sent[key] == value) return;

    for (int attempt = 0; attempt < 2; attempt++) {
      if (_generation != generation || !_isCurrentAdmin(userId)) return;
      try {
        await register(<String, Object?>{key: value});
        if (_generation == generation && _isCurrentAdmin(userId)) _sent[key] = value;
        return;
      } catch (error, stackTrace) {
        logger.w('Review Live Activity token sync failed', tag: 'live_activity', error: error, stackTrace: stackTrace);
        if (attempt == 0) await Future<void>.delayed(retryDelay);
      }
    }
  }

  static bool _isCurrentAdmin(String? userId) =>
      userId != null && userId.isNotEmpty && userId == currentUserId() && userId == app_state.prismUser.id && isAdmin();

  static void _invalidateSession() {
    instance._generation++;
    instance._ownerId = null;
    instance._sent.clear();
  }

  static Future<void> _callRegister(Map<String, Object?> data) async {
    await appFunctions.httpsCallable('registerReviewLiveActivity').call<Object?>(data);
  }

  @visibleForTesting
  static Future<void> settleForTest() => instance._sendTail;

  @visibleForTesting
  static void resetForTest() {
    _invalidateSession();
    instance._sendTail = Future<void>.value();
  }
}
