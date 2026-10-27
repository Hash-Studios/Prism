import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/platform/ios_widget_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_widget_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter/foundation.dart';

/// Mirrors the signed-in user's streak to the iOS Lock Screen widgets, so they stay right after midnight without the
/// app. Never throws.
class StreakWidgetSync {
  const StreakWidgetSync._();

  @visibleForTesting
  static ValueListenable<StreakStatus> Function() streak = () => CoinsService.instance.streakNotifier;

  @visibleForTesting
  static bool Function() isSignedIn = () => app_state.prismUser.loggedIn;

  static ValueListenable<StreakStatus>? _listening;
  static String? _lastSent;

  static void start() {
    final ValueListenable<StreakStatus> current = streak();
    if (!identical(_listening, current)) {
      _listening?.removeListener(_write);
      current.addListener(_write);
      _listening = current;
    }
    _write();
  }

  static void _write() {
    unawaited(_send());
  }

  static Future<void> _send() async {
    final StreakStatus status = streak().value;
    final bool signedIn = isSignedIn();
    if (signedIn && identical(status, StreakStatus.empty)) return;
    final StreakWidgetSnapshot? snapshot = snapshotFor(status, signedIn: signedIn);
    final String key = snapshot == null
        ? ''
        : '${snapshot.count}|${snapshot.lastKeptDay}|${snapshot.utcOffsetMinutes}|${snapshot.freezes}';
    if (key == _lastSent) return;
    _lastSent = key;
    await IosWidgetChannel.setStreak(snapshot);
  }

  @visibleForTesting
  static StreakWidgetSnapshot? snapshotFor(StreakStatus status, {required bool signedIn}) {
    if (!signedIn) return null;
    return StreakWidgetSnapshot(
      count: status.count,
      lastKeptDay: status.lastClaimDate,
      utcOffsetMinutes: status.timezoneOffsetMinutes,
      freezes: status.freezes,
    );
  }

  @visibleForTesting
  static void resetForTest() {
    _listening?.removeListener(_write);
    _listening = null;
    _lastSent = null;
  }
}
