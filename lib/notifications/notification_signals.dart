import 'dart:async';
import 'dart:math';

import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/firestore/firestore_sentinels.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/notification_retention.dart';

class _NotificationSignalQueue {
  Future<void> _tail = Future<void>.value();

  Future<void> run(Future<void> Function() action) async {
    final Future<void> previous = _tail;
    final Completer<void> done = Completer<void>();
    _tail = done.future;
    await previous;
    try {
      await action();
    } finally {
      done.complete();
    }
  }
}

/// Writes the last-open stamp and best-effort scoreboard signals, retaining pending returns locally.
class NotificationSignals {
  NotificationSignals({
    Future<bool> Function()? isReady,
    SettingsLocalDataSource? settings,
    String Function()? currentUserId,
    Future<void> Function(Map<String, dynamic> data)? call,
    Future<void> Function(String userId, DateTime now, int timezoneOffsetMinutes)? writeAppOpenStamp,
    DateTime Function()? clock,
  }) : _isReady = isReady ?? (() => FirebaseInit.readyFuture),
       _providedSettings = settings,
       _currentUserId = currentUserId ?? _defaultUserId,
       _callSignal = call ?? _callFirebase,
       _writeAppOpenStamp = writeAppOpenStamp ?? _writeFirebaseAppOpenStamp,
       _clock = clock ?? DateTime.now;

  static final NotificationSignals instance = NotificationSignals();

  final Future<bool> Function() _isReady;
  final SettingsLocalDataSource? _providedSettings;
  final String Function() _currentUserId;
  final Future<void> Function(Map<String, dynamic> data) _callSignal;
  final Future<void> Function(String userId, DateTime now, int timezoneOffsetMinutes) _writeAppOpenStamp;
  final DateTime Function() _clock;

  final _NotificationSignalQueue _settingsQueue = _NotificationSignalQueue();

  Future<void> onTap(String kind) async {
    try {
      await _withSettings((SettingsLocalDataSource settings) async {
        final String userId = _currentUserId().trim();
        await _synchronizeLocalUser(settings, userId);
        final DateTime now = _clock();
        final PendingPushReturns? current = decodePending(
          settings.get<String>(PersistenceKeys.pushReturnPending, defaultValue: ''),
        );
        final List<String> due = returnsToReport(current, now);
        bool reported = false;
        if (due.isNotEmpty) {
          try {
            reported = await _reportReturns(due, userId);
          } catch (error, stackTrace) {
            logger.w('Next-day return score failed.', tag: 'Push', error: error, stackTrace: stackTrace);
          }
        }
        final PendingPushReturns? next = pendingAfterTapAttempt(
          current: current,
          kind: kind,
          now: now,
          returnReportSucceeded: reported,
        );
        if (_currentUserId().trim() == userId && next != null) {
          await settings.set(PersistenceKeys.pushReturnPending, encodePending(next));
        }
        if (userId.isNotEmpty && _currentUserId().trim() == userId) {
          await _call(type: 'tap', kind: kind);
        }
      });
    } catch (error, stackTrace) {
      logger.w('Push tap score failed.', tag: 'Push', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> onResumed() async {
    try {
      await _withSettings((SettingsLocalDataSource settings) async {
        final String userId = _currentUserId().trim();
        await _synchronizeLocalUser(settings, userId);
        final DateTime now = _clock();
        final PendingPushReturns? current = decodePending(
          settings.get<String>(PersistenceKeys.pushReturnPending, defaultValue: ''),
        );
        final List<String> due = returnsToReport(current, now);
        try {
          if (due.isNotEmpty && current != null && userId.isNotEmpty && await _reportReturns(due, userId)) {
            if (_currentUserId().trim() != userId) return;
            await settings.set(PersistenceKeys.pushReturnPending, encodePending(markReported(current, due)));
          }
        } catch (error, stackTrace) {
          logger.w('Next-day return score failed.', tag: 'Push', error: error, stackTrace: stackTrace);
        }
        await _stampOpen(settings, now, userId);
      });
    } catch (error, stackTrace) {
      logger.w('App open stamp failed.', tag: 'Push', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> onPermission(bool granted) async {
    try {
      await _withSettings((SettingsLocalDataSource settings) async {
        final String currentUserId = _currentUserId().trim();
        await _synchronizeLocalUser(settings, currentUserId);
        final String? userId = currentUserId.isNotEmpty ? currentUserId : null;
        String? installId;
        if (userId == null) {
          installId = settings.get<String>(PersistenceKeys.notificationInstallId, defaultValue: '');
          if (installId.isEmpty) {
            installId = _newInstallId();
            await settings.set(PersistenceKeys.notificationInstallId, installId);
          }
        }
        if (_currentUserId().trim() != (userId ?? '')) return;
        await _call(type: 'permission', result: granted ? 'granted' : 'declined', installId: installId);
      });
    } catch (error, stackTrace) {
      logger.w('Permission score failed.', tag: 'Push', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _stampOpen(SettingsLocalDataSource settings, DateTime now, String userId) async {
    if (userId.isEmpty || _currentUserId().trim() != userId) return;
    final DateTime? last = DateTime.tryParse(
      settings.get<String>(PersistenceKeys.appOpenStampedAtUtc, defaultValue: ''),
    );
    if (!shouldStampAppOpen(last: last, now: now)) return;
    await _writeAppOpenStamp(userId, now, roundedTimezoneOffsetMinutes(now.timeZoneOffset));
    if (_currentUserId().trim() != userId) return;
    await settings.set(PersistenceKeys.appOpenStampedAtUtc, now.toUtc().toIso8601String());
  }

  static Future<void> _writeFirebaseAppOpenStamp(String userId, DateTime now, int timezoneOffsetMinutes) async {
    await firestoreClient.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
      'lastAppOpenAt': FirestoreSentinels.serverTimestamp(),
      'appOpenTimezoneOffsetMinutes': timezoneOffsetMinutes,
    }, sourceTag: 'retention.app_open');
  }

  Future<bool> _reportReturns(List<String> kinds, String userId) async {
    if (userId.isEmpty) return false;
    for (final String kind in kinds) {
      if (_currentUserId().trim() != userId) return false;
      await _call(type: 'returned_next_day', kind: kind);
    }
    return true;
  }

  Future<void> _call({required String type, String? kind, String? result, String? installId}) async {
    await _callSignal(<String, dynamic>{
      'type': type,
      if (kind != null) 'kind': kind,
      if (result != null) 'result': result,
      if (installId != null) 'installId': installId,
    });
  }

  Future<void> _withSettings(Future<void> Function(SettingsLocalDataSource settings) action) async {
    await _settingsQueue.run(() async {
      if (!await _isReady()) return;
      final SettingsLocalDataSource? providedSettings = _providedSettings;
      if (providedSettings != null) {
        if (!providedSettings.isOpen) return;
        await action(providedSettings);
        return;
      }
      if (!getIt.isRegistered<SettingsLocalDataSource>()) return;
      final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
      if (!settings.isOpen) return;
      await action(settings);
    });
  }

  Future<void> _synchronizeLocalUser(SettingsLocalDataSource settings, String userId) async {
    final String previousUserId = settings.get<String>(PersistenceKeys.notificationSignalUserId, defaultValue: '');
    if (previousUserId == userId) return;
    await settings.delete(PersistenceKeys.pushReturnPending);
    await settings.delete(PersistenceKeys.appOpenStampedAtUtc);
    await settings.set(PersistenceKeys.notificationSignalUserId, userId);
  }

  static String _defaultUserId() => app_state.prismUser.loggedIn ? app_state.prismUser.id : '';

  static Future<void> _callFirebase(Map<String, dynamic> data) async {
    await appFunctions.httpsCallable('recordNotificationSignal').call(data);
  }

  String _newInstallId() {
    final Random random = Random.secure();
    return List<String>.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
