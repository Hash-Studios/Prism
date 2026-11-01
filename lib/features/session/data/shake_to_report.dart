import 'dart:math';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:flutter/foundation.dart';

/// Sentry environments where shake to report starts off. Every other environment, and every debug build, starts on.
/// The user's own choice in Settings always wins.
const Set<String> shakeToReportOffByDefaultIn = <String>{'production'};

/// The "Shake to report" setting.
// ignore: avoid_classes_with_only_static_members
abstract final class ShakeToReport {
  static const String settingsKey = 'shakeToReport';

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(_readStored());

  static bool get defaultValue =>
      kDebugMode || !shakeToReportOffByDefaultIn.contains(MonitoringRuntime.config?.environment ?? 'production');

  static bool _readStored() {
    try {
      if (!getIt.isRegistered<SettingsLocalDataSource>()) return defaultValue;
      final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
      return settings.isOpen ? settings.get<bool>(settingsKey, defaultValue: defaultValue) : defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  static Future<void> set(bool value) async {
    enabled.value = value;
    await getIt<SettingsLocalDataSource>().set(settingsKey, value);
  }
}

/// Turns accelerometer samples (m/s², gravity removed) into shakes. A jolt is a sample above [threshold] at least
/// [minGap] after the last jolt; [jolts] of them inside [window] make a shake. After a shake it stays quiet for
/// [cooldown].
class ShakeDetector {
  ShakeDetector({
    this.threshold = 20,
    this.jolts = 3,
    this.minGap = const Duration(milliseconds: 120),
    this.window = const Duration(milliseconds: 1200),
    this.cooldown = const Duration(seconds: 3),
  });

  // ponytail: one fixed threshold for every phone; tune it here if real devices fire too easily or too rarely.
  final double threshold;
  final int jolts;
  final Duration minGap;
  final Duration window;
  final Duration cooldown;

  final List<DateTime> _recent = <DateTime>[];
  DateTime? _quietUntil;

  /// Drops partial motion samples when sensor listening pauses.
  void reset() => _recent.clear();

  /// Returns true when this sample completes a shake.
  bool add(double x, double y, double z, DateTime at) {
    if (_quietUntil != null && at.isBefore(_quietUntil!)) return false;
    if (sqrt(x * x + y * y + z * z) < threshold) return false;
    if (_recent.isNotEmpty && at.difference(_recent.last) < minGap) return false;
    _recent
      ..add(at)
      ..removeWhere((DateTime t) => at.difference(t) > window);
    if (_recent.length < jolts) return false;
    _recent.clear();
    _quietUntil = at.add(cooldown);
    return true;
  }
}
