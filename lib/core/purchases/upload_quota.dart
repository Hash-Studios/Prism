import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/logger/logger.dart';

class UploadQuota {
  const UploadQuota._();

  static const int freeUploadsPerWeek = 3;
  static const String _weekStartPrefKey = 'uploadsWeekStart';
  static const String _weeklyCountPrefKey = 'uploadsThisWeek';
  static Future<void> _writeTail = Future<void>.value();
  static SettingsLocalDataSource get _settings => getIt<SettingsLocalDataSource>();

  static String get storedWeekStart => _settings.get<String>(_weekStartPrefKey, defaultValue: '').trim();

  static DateTime _startOfWeek(DateTime now) {
    final DateTime local = now.toLocal();
    final int daysFromMonday = local.weekday - DateTime.monday;
    return DateTime(local.year, local.month, local.day).subtract(Duration(days: daysFromMonday));
  }

  static String _weekKey(DateTime now) => _startOfWeek(now).toIso8601String();

  static int _readCountForCurrentWeek(DateTime now) {
    final String currentWeekKey = _weekKey(now);
    if (storedWeekStart != currentWeekKey) {
      unawaited(
        Future.wait<void>([
          _settings.set(_weekStartPrefKey, currentWeekKey),
          _settings.set(_weeklyCountPrefKey, 0),
        ]).then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            logger.w('Could not reset weekly upload quota', tag: 'Upload', error: error, stackTrace: stackTrace);
          },
        ),
      );
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

  static Future<int> incrementWeeklyUploads({DateTime? now, String? ownerUid, String? operationId}) {
    final settings = _settings;
    final target = now ?? DateTime.now();
    final result = _writeTail.then((_) async {
      final week = _weekKey(target);
      final storedWeek = settings.get<String>(_weekStartPrefKey, defaultValue: '');
      var used = storedWeek == week ? settings.get<int>(_weeklyCountPrefKey, defaultValue: 0) : 0;
      final receiptKey = ownerUid == null || operationId == null ? null : 'uploadQuotaOperations/$ownerUid';
      final receipts = receiptKey == null
          ? <String, Object?>{}
          : Map<String, Object?>.from(settings.get<Map>(receiptKey, defaultValue: const <String, Object?>{}));
      final receipt = receipts[operationId];
      if (receipt is Map && (receipt['done'] == true || receipt['week'] != week)) return used;
      final next = receipt is Map ? (receipt['count'] as int) : used + 1;
      if (receiptKey != null && receipt == null) {
        receipts[operationId!] = <String, Object?>{'week': week, 'count': next};
        await settings.set(receiptKey, receipts);
      }
      // A durable target makes a crash between the counter write and its acknowledgement replay-safe.
      if (storedWeek != week) {
        await settings.set(_weeklyCountPrefKey, 0);
        await settings.set(_weekStartPrefKey, week);
      }
      used = used > next ? used : next;
      await settings.set(_weeklyCountPrefKey, used);
      if (receiptKey != null) {
        receipts[operationId!] = <String, Object?>{'week': week, 'count': next, 'done': true};
        await settings.set(receiptKey, receipts);
      }
      return used;
    });
    _writeTail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static Future<void> clearOperationsForUser(String ownerUid) {
    final settings = _settings;
    final result = _writeTail.then((_) => settings.delete('uploadQuotaOperations/$ownerUid'));
    _writeTail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
