import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';

typedef _ReadSetting = T Function<T>(String key, T defaultValue);
typedef _WriteSetting = Future<void> Function(String key, Object? value);

/// Counts app sessions and remembers the first launch. The count goes up once per process, on the first call to
/// [sessionNumber].
class AppSessionTracker {
  AppSessionTracker({_ReadSetting? read, _WriteSetting? write, DateTime Function()? clock})
    : _read = read ?? _defaultRead,
      _write = write ?? _defaultWrite,
      _clock = clock ?? DateTime.now;

  static final AppSessionTracker instance = AppSessionTracker();

  static const String sessionCountKey = 'app.session_count';
  static const String firstLaunchKey = 'app.first_launch_at';

  final _ReadSetting _read;
  final _WriteSetting _write;
  final DateTime Function() _clock;

  int? _sessionNumber;

  /// The number of this session. The first session ever is 1.
  int get sessionNumber => _count();

  int _count() {
    final int? cached = _sessionNumber;
    if (cached != null) return cached;
    final int next = _read<int>(sessionCountKey, 0) + 1;
    _sessionNumber = next;
    unawaited(_write(sessionCountKey, next));
    if (_read<String>(firstLaunchKey, '').isEmpty) {
      unawaited(_write(firstLaunchKey, _clock().toUtc().toIso8601String()));
    }
    return next;
  }

  /// When the app first ran with this tracker, or now when it has not been recorded yet.
  DateTime get firstLaunchAt {
    _count();
    return DateTime.tryParse(_read<String>(firstLaunchKey, ''))?.toUtc() ?? _clock().toUtc();
  }

  static T _defaultRead<T>(String key, T defaultValue) {
    return getIt<SettingsLocalDataSource>().get<T>(key, defaultValue: defaultValue);
  }

  static Future<void> _defaultWrite(String key, Object? value) => getIt<SettingsLocalDataSource>().set(key, value);
}
