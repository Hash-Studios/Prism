import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';

class UploadQuota {
  const UploadQuota._();

  static const int freeUploadsPerWeek = 3;
  static const String _weekStartPrefKey = 'uploadsWeekStart';
  static const String _weeklyCountPrefKey = 'uploadsThisWeek';
  static SettingsLocalDataSource get _settings => getIt<SettingsLocalDataSource>();

  static DateTime _startOfWeek(DateTime now) {
    final DateTime local = now.toLocal();
    final int daysFromMonday = local.weekday - DateTime.monday;
    return DateTime(local.year, local.month, local.day).subtract(Duration(days: daysFromMonday));
  }

  static String _weekKey(DateTime now) => _startOfWeek(now).toIso8601String();

  static int _readCountForCurrentWeek(DateTime now) {
    final String currentWeekKey = _weekKey(now);
    final String storedWeekKey = _settings.get<String>(_weekStartPrefKey, defaultValue: '').trim();
    if (storedWeekKey != currentWeekKey) {
      _settings.set(_weekStartPrefKey, currentWeekKey);
      _settings.set(_weeklyCountPrefKey, 0);
      return 0;
    }
    return _settings.get<int>(_weeklyCountPrefKey, defaultValue: 0);
  }

  static int currentUploadsThisWeek({DateTime? now}) {
    return _readCountForCurrentWeek(now ?? DateTime.now());
  }

  static bool hasFreeUploadQuotaRemaining({DateTime? now}) {
    return currentUploadsThisWeek(now: now) < freeUploadsPerWeek;
  }

  static int remainingFreeUploadsThisWeek({DateTime? now}) {
    final int used = currentUploadsThisWeek(now: now);
    return (freeUploadsPerWeek - used).clamp(0, freeUploadsPerWeek);
  }

  static int incrementWeeklyUploads({DateTime? now}) {
    final DateTime target = now ?? DateTime.now();
    final int used = _readCountForCurrentWeek(target) + 1;
    _settings.set(_weeklyCountPrefKey, used);
    return used;
  }
}
