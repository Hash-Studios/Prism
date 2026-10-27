import 'dart:io';

import 'package:Prism/core/platform/pigeon/prism_widget_api.g.dart';
import 'package:flutter/foundation.dart';

/// iOS Home Screen and Lock Screen widgets. Every call is a no-op on other platforms and never throws.
class IosWidgetChannel {
  const IosWidgetChannel._();

  @visibleForTesting
  static PrismWidgetHostApi api = PrismWidgetHostApi();

  @visibleForTesting
  static bool Function() isSupportedPlatform = () => !kIsWeb && Platform.isIOS;

  static Future<void> _streakQueue = Future<void>.value();
  static int _streakGeneration = 0;

  static int get streakGeneration => _streakGeneration;

  static Future<bool> setStreak(StreakWidgetSnapshot? snapshot) {
    return _enqueueStreak(snapshot, _streakGeneration);
  }

  static Future<bool> _enqueueStreak(StreakWidgetSnapshot? snapshot, int generation) {
    final Future<bool> result = _streakQueue.then((_) async {
      if (snapshot != null && generation != _streakGeneration) return false;
      try {
        if (!isSupportedPlatform()) return true;
        await api.setStreakSnapshot(snapshot);
        return true;
      } on Object {
        return false;
      }
    });
    _streakQueue = result.then<void>((_) {});
    return result;
  }

  static Future<bool> requestClearStreak() {
    _streakGeneration++;
    return _enqueueStreak(null, _streakGeneration);
  }

  static Future<void> clearStreak() => requestClearStreak().then<void>((_) {});

  static Future<void> reloadWallOfTheDay() async {
    if (!isSupportedPlatform()) return;
    try {
      await api.reloadWallOfTheDay();
    } on Object {
      return;
    }
  }
}
