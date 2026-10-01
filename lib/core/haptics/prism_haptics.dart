import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The one place the app plays haptics. Do not call [HapticFeedback] directly.
///
/// Pick by meaning, not by strength:
/// - [selection]: a value changed (tab, chip, switch, segment).
/// - [tap]: a button or tile that starts an action or opens something.
/// - [impact]: a weighty commit (long press, pull to refresh, favourite, swipe to dismiss).
/// - [success], [warning], [error]: the outcome of an action.
///
/// iOS uses the UIKit feedback generators. Android uses a native channel with device tuned
/// vibration effects, because Flutter's Android mapping is weak or silent on many phones.
// ignore: avoid_classes_with_only_static_members
abstract final class PrismHaptics {
  /// Settings key (in the `settings.` scope) for the user toggle.
  static const String settingsKey = 'hapticsEnabled';

  /// Set from settings at startup and by the settings toggle.
  static bool enabled = true;

  static const MethodChannel _android = MethodChannel('prism/haptics');

  static void selection() => _play('selection');

  static void tap() => _play('tap');

  static void impact() => _play('impact');

  static void success() => _play('success');

  static void warning() => _play('warning');

  static void error() => _play('error');

  static void _play(String type) {
    if (!enabled) return;
    unawaited(_send(type).catchError((Object _) {}));
  }

  static Future<void> _send(String type) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _android.invokeMethod<void>('play', type);
    }
    return switch (type) {
      'selection' => HapticFeedback.selectionClick(),
      'tap' => HapticFeedback.lightImpact(),
      'impact' => HapticFeedback.mediumImpact(),
      'success' => HapticFeedback.successNotification(),
      'warning' => HapticFeedback.warningNotification(),
      _ => HapticFeedback.errorNotification(),
    };
  }
}
