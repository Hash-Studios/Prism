import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/annual_trial.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/views/widgets/notification_settings_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
// zonedSchedule takes a TZDateTime. flutter_local_notifications depends on timezone, so this adds no package.
// ignore: depend_on_referenced_packages
import 'package:timezone/timezone.dart' as tz;

String storeNameForPlatform() => Platform.isIOS ? 'App Store' : 'Google Play';

/// Keeps the "trial ends soon" reminder and the trial analytics in step with each CustomerInfo the app receives.
///
/// The reminder time comes from the store's trial end date, never from when the user tapped. It is moved when that
/// date changes, and removed once the trial converts, is cancelled, or is refunded.
class TrialReminder {
  TrialReminder({
    required SettingsLocalDataSource? Function() settings,
    required Future<void> Function(DateTime at, String title, String body) schedule,
    required Future<void> Function() cancel,
    required Future<bool> Function() isScheduled,
    required Future<bool> Function() permissionGranted,
    required Future<void> Function(InAppNotificationEntity item) postInbox,
    required void Function(AnalyticsEvent event) track,
    required Future<AppLocalizations> Function() localizations,
    required String storeName,
    DateTime Function()? now,
  }) : _settings = settings,
       _schedule = schedule,
       _cancel = cancel,
       _isScheduled = isScheduled,
       _permissionGranted = permissionGranted,
       _postInbox = postInbox,
       _track = track,
       _localizations = localizations,
       _storeName = storeName,
       _now = now ?? DateTime.now;

  static final TrialReminder instance = TrialReminder(
    settings: () {
      if (!getIt.isRegistered<SettingsLocalDataSource>()) return null;
      final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
      return settings.isOpen ? settings : null;
    },
    schedule: _scheduleNotification,
    cancel: () => FlutterLocalNotificationsPlugin().cancel(id: notificationId),
    isScheduled: () async =>
        (await FlutterLocalNotificationsPlugin().pendingNotificationRequests()).any((r) => r.id == notificationId),
    permissionGranted: () => const NotificationPermissionGateway().isGranted(),
    postInbox: (InAppNotificationEntity item) =>
        getIt<NotificationsLocalDataSource>().upsertAll(<InAppNotificationEntity>[item]),
    track: analytics.track,
    localizations: loadDeviceAppLocalizations,
    storeName: storeNameForPlatform(),
  );

  static const int notificationId = 290729;
  static const Duration lead = Duration(days: 2);
  static const String optInKey = 'trialReminderOptIn';
  static const String _reminderKey = 'trialReminder';
  static const String _statePrefix = 'trialState.';
  static const String channelId = 'subscription';

  final SettingsLocalDataSource? Function() _settings;
  final Future<void> Function(DateTime at, String title, String body) _schedule;
  final Future<void> Function() _cancel;
  final Future<bool> Function() _isScheduled;
  final Future<bool> Function() _permissionGranted;
  final Future<void> Function(InAppNotificationEntity item) _postInbox;
  final void Function(AnalyticsEvent event) _track;
  final Future<AppLocalizations> Function() _localizations;
  final String _storeName;
  final DateTime Function() _now;
  Future<void> _queue = Future<void>.value();

  /// The choice from the trial timeline toggle. It applies to the next trial this device sees.
  Future<void> setOptIn(bool enabled) async => _settings()?.set(optInKey, enabled);

  /// Safe to call for every CustomerInfo update: the result depends only on the info and the stored state.
  Future<void> apply(CustomerInfo info, {required String userId}) {
    final Future<void> run = _queue.then((_) => _apply(info, userId));
    _queue = run.catchError((Object _) {});
    return run;
  }

  Future<void> _apply(CustomerInfo info, String userId) async {
    final SettingsLocalDataSource? settings = _settings();
    if (settings == null || userId.isEmpty) return;
    final ActiveTrial? trial = activeTrialFrom(info);
    await _trackTransition(settings, info, trial, userId);
    await _reconcile(settings, trial, userId);
  }

  Future<void> _trackTransition(
    SettingsLocalDataSource settings,
    CustomerInfo info,
    ActiveTrial? trial,
    String userId,
  ) async {
    final String key = '$_statePrefix$userId';
    final List<String> previous = settings.get<String>(key, defaultValue: '').split('|');
    final bool hadTrial = previous.length == 3;
    final bool previousWillRenew = hadTrial && previous[2] == '1';
    if (trial != null) {
      if (!hadTrial) {
        _track(TrialStartedEvent(productId: trial.productId));
      } else if (previousWillRenew && !trial.willRenew) {
        _track(TrialCancelledEvent(productId: trial.productId, reason: 'auto_renew_off'));
      }
      await settings.set(key, '${trial.productId}|${trial.endsAt.millisecondsSinceEpoch}|${trial.willRenew ? 1 : 0}');
      return;
    }
    if (!hadTrial) return;
    final String productId = previous[0];
    final bool converted = info.entitlements.active.values.any(
      (EntitlementInfo e) => e.productIdentifier == productId && e.periodType != PeriodType.trial,
    );
    if (converted) {
      _track(TrialConvertedEvent(productId: productId));
    } else if (previousWillRenew) {
      // Auto-renew was on, so the trial did not end by the user's choice: a refund, a revoke, or a failed charge.
      final bool refunded = info.subscriptionsByProductIdentifier[productId]?.refundedAt != null;
      _track(TrialCancelledEvent(productId: productId, reason: refunded ? 'refunded' : 'ended'));
    }
    await settings.delete(key);
  }

  Future<void> _reconcile(SettingsLocalDataSource settings, ActiveTrial? trial, String userId) async {
    final String stored = settings.get<String>(_reminderKey, defaultValue: '');
    final bool wanted = trial != null && trial.willRenew && settings.get<bool>(optInKey, defaultValue: false);
    if (!wanted) {
      if (stored.isNotEmpty) {
        await _cancel();
        await settings.delete(_reminderKey);
      }
      return;
    }
    final DateTime now = _now();
    final DateTime remindAt = trial.endsAt.subtract(lead);
    final String target = '$userId|${trial.endsAt.millisecondsSinceEpoch}';
    if (await _permissionGranted()) {
      if (!remindAt.isAfter(now)) return;
      if (stored == '$target|notification' && await _isScheduled()) return;
      final ({String title, String body}) copy = await _copy(trial);
      await _schedule(remindAt, copy.title, copy.body);
      await settings.set(_reminderKey, '$target|notification');
      return;
    }
    if (stored.endsWith('|notification')) await _cancel();
    if (now.isBefore(remindAt) || !now.isBefore(trial.endsAt) || stored == '$target|inbox') {
      if (stored.endsWith('|notification')) await settings.delete(_reminderKey);
      return;
    }
    final ({String title, String body}) copy = await _copy(trial);
    await _postInbox(
      InAppNotificationEntity(
        id: 'trial_reminder_${trial.endsAt.millisecondsSinceEpoch}',
        title: copy.title,
        body: copy.body,
        pageName: '',
        imageUrl: '',
        arguments: const <Object>[],
        url: '',
        createdAt: now.toUtc(),
        read: false,
        route: '/premium',
        kind: InAppNotificationKind.generic,
      ),
    );
    await settings.set(_reminderKey, '$target|inbox');
  }

  Future<({String title, String body})> _copy(ActiveTrial trial) async {
    final AppLocalizations l10n = await _localizations();
    // This can run at app start, before the Material localizations load the date data.
    await initializeDateFormatting(l10n.localeName);
    final String date = DateFormat.yMMMd(l10n.localeName).format(trial.endsAt.toLocal());
    return (title: l10n.trialReminderTitle(date), body: l10n.trialReminderBody(_storeName));
  }

  static Future<void> _scheduleNotification(DateTime at, String title, String body) async {
    final AppLocalizations l10n = await loadDeviceAppLocalizations();
    await FlutterLocalNotificationsPlugin().zonedSchedule(
      id: notificationId,
      // UTC needs no time zone database, and the instant is absolute.
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          l10n.notifChannelSubscription,
          channelDescription: l10n.notifChannelSubscriptionDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: jsonEncode(<String, String>{'route': '/premium'}),
    );
  }
}
