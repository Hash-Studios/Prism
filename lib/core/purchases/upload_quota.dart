import 'package:Prism/main.dart' as main;

class UploadQuota {
  const UploadQuota._();

  static const int freeUploadsPerWeek = 3;
  static const String _weekStartPrefKey = 'uploadsWeekStart';
  static const String _weeklyCountPrefKey = 'uploadsThisWeek';

  static DateTime _startOfWeek(DateTime now) {
    final DateTime local = now.toLocal();
    final int daysFromMonday = local.weekday - DateTime.monday;
    return DateTime(local.year, local.month, local.day).subtract(Duration(days: daysFromMonday));
  }

  static String _weekKey(DateTime now) => _startOfWeek(now).toIso8601String();

  static int _readCountForCurrentWeek(DateTime now) {
    final String currentWeekKey = _weekKey(now);
    final String storedWeekKey = (main.prefs.get(_weekStartPrefKey, defaultValue: '') as String?)?.trim() ?? '';
    if (storedWeekKey != currentWeekKey) {
      main.prefs.put(_weekStartPrefKey, currentWeekKey);
      main.prefs.put(_weeklyCountPrefKey, 0);
      return 0;
    }
    return (main.prefs.get(_weeklyCountPrefKey, defaultValue: 0) as int?) ?? 0;
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
    main.prefs.put(_weeklyCountPrefKey, used);
    return used;
  }
}
