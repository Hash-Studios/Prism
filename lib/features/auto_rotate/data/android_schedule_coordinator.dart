import 'dart:convert';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter/foundation.dart';

/// Serializes the two Android schedules, including their saved enabled flags.
final class AndroidScheduleCoordinator {
  AndroidScheduleCoordinator._(this._settings);

  static final Expando<AndroidScheduleCoordinator> _instances = Expando<AndroidScheduleCoordinator>();

  factory AndroidScheduleCoordinator.forSettings(SettingsLocalDataSource settings) =>
      _instances[settings] ??= AndroidScheduleCoordinator._(settings);

  final SettingsLocalDataSource _settings;
  Future<void>? _pending;
  int _claim = 0;
  bool _dayNightClaimed = false;

  int get claim => _claim;

  int claimDayNight() {
    _dayNightClaimed = true;
    return ++_claim;
  }

  void releaseDayNight(int claim) {
    if (claim == _claim) _dayNightClaimed = false;
  }

  bool get dayNightEnabled {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    if (_dayNightClaimed) return true;
    final String raw = _settings.get<String>('dayNight.pair', defaultValue: '');
    try {
      final Object? pair = jsonDecode(raw);
      return pair is Map<String, Object?> &&
          pair['enabled'] == true &&
          app_state.prismUser.loggedIn &&
          pair['ownerId'] == app_state.prismUser.id.trim();
    } on FormatException {
      return false;
    }
  }

  Future<T> run<T>(Future<T> Function() operation) {
    final Future<void>? pending = _pending;
    final Future<T> next = pending == null
        ? operation()
        : pending.then((_) => operation(), onError: (Object _, StackTrace _) => operation());
    final Future<void> settled = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _pending = settled;
    return next.whenComplete(() {
      if (identical(_pending, settled)) _pending = null;
    });
  }
}
