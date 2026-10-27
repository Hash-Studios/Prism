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

  static Future<void> setStreak(StreakWidgetSnapshot? snapshot) async {
    if (!isSupportedPlatform()) return;
    try {
      await api.setStreakSnapshot(snapshot);
    } on Object {
      return;
    }
  }

  static Future<void> clearStreak() => setStreak(null);

  static Future<void> reloadWallOfTheDay() async {
    if (!isSupportedPlatform()) return;
    try {
      await api.reloadWallOfTheDay();
    } on Object {
      return;
    }
  }
}
