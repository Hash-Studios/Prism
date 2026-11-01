import 'package:Prism/core/startup/firebase_init.dart';
import 'package:flutter/foundation.dart';

class DailyMomentConfig {
  DailyMomentConfig._();
  static const String key = 'daily_moment_v1';

  @visibleForTesting
  static bool? enabledOverride;

  static bool get enabled {
    if (enabledOverride case final enabled?) return enabled;
    final String value = FirebaseInit.remoteConfigIfInitialized?.getString(key).trim().toLowerCase() ?? '';
    return switch (value) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => kDebugMode,
    };
  }
}
