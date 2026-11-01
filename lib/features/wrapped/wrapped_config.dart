import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/env/env.dart';
import 'package:flutter/foundation.dart';

/// Remote Config gate for Wrapped: an on/off flag plus the window the Home card shows in. Dates are local calendar days,
/// `wrapped_2026_end` inclusive. Debug builds default to on, release builds to off.
class WrappedConfig {
  WrappedConfig._();

  static const String enabledKey = 'wrapped_2026_enabled';
  static const String startKey = 'wrapped_2026_start';
  static const String endKey = 'wrapped_2026_end';
  static final DateTime defaultStart = DateTime(2026, 12);
  static final DateTime defaultEnd = DateTime(2027, 1, 15);

  @visibleForTesting
  static ({bool enabled, DateTime start, DateTime end})? override;

  static bool get enabled =>
      override?.enabled ??
      switch (_read(enabledKey).toLowerCase()) {
        'true' || '1' => true,
        'false' || '0' => false,
        _ => kDebugMode,
      };

  static DateTime get start => override?.start ?? DateTime.tryParse(_read(startKey)) ?? defaultStart;
  static DateTime get end => override?.end ?? DateTime.tryParse(_read(endKey)) ?? defaultEnd;

  /// True while the flag is on and [now] falls on a day from [start] to [end].
  static bool isOpen(DateTime now) {
    if (kDebugMode && Env.wrappedQaOpen && override == null) return true;
    final DateTime day = DateTime(now.year, now.month, now.day);
    return enabled && !day.isBefore(_day(start)) && !day.isAfter(_day(end));
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _read(String key) => FirebaseInit.remoteConfigIfInitialized?.getString(key).trim() ?? '';
}
