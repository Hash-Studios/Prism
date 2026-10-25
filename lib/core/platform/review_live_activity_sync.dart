import 'dart:async';

import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/platform/live_activity_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_live_activity_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';

/// Sends this device's review queue Live Activity tokens to the server, for admins on iOS. Never throws.
class ReviewLiveActivitySync implements PrismLiveActivityFlutterApi {
  ReviewLiveActivitySync._();
  static final ReviewLiveActivitySync instance = ReviewLiveActivitySync._();

  @visibleForTesting
  static Future<void> Function(Map<String, Object?> data) register = _callRegister;
  @visibleForTesting
  static bool Function() isAdmin = () => app_state.prismUser.loggedIn && app_state.isAdminUser();

  final Map<String, String?> _sent = <String, String?>{};

  /// Asks the native side for the latest tokens. Call it after the signed-in user is known; it is safe to call again.
  static Future<void> start() async {
    if (!LiveActivityChannel.isSupported || !isAdmin()) return;
    PrismLiveActivityFlutterApi.setUp(instance);
    await LiveActivityChannel.startReviewTokenUpdates();
  }

  @override
  void onReviewPushToStartToken(String token) => unawaited(_send('pushToStartToken', token));

  @override
  void onReviewActivityToken(String? token) => unawaited(_send('activityToken', token));

  Future<void> _send(String key, String? value) async {
    if (!isAdmin()) return;
    if (_sent.containsKey(key) && _sent[key] == value) return;
    try {
      await register(<String, Object?>{key: value});
      _sent[key] = value;
    } catch (error, stackTrace) {
      logger.w('Review Live Activity token sync failed', tag: 'live_activity', error: error, stackTrace: stackTrace);
    }
  }

  static Future<void> _callRegister(Map<String, Object?> data) async {
    await appFunctions.httpsCallable('registerReviewLiveActivity').call<Object?>(data);
  }

  @visibleForTesting
  static void resetForTest() => instance._sent.clear();
}
