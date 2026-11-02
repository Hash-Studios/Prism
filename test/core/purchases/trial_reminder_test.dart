import 'dart:async';
import 'dart:io';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/trial_reminder.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../support/in_memory_local_store.dart';

class _ScheduledReminder {
  const _ScheduledReminder(this.at, this.title, this.body);

  final DateTime at;
  final String title;
  final String body;
}

class _Harness {
  _Harness({this.scheduleOverride, this.postInboxOverride, this.isCurrentUser, this.isNotificationOwner});

  final Future<void> Function(DateTime at, String title, String body)? scheduleOverride;
  final Future<void> Function(InAppNotificationEntity item)? postInboxOverride;
  final bool Function(String userId)? isCurrentUser;
  final bool Function(String userId)? isNotificationOwner;
  final InMemoryLocalStore store = InMemoryLocalStore();
  late final SettingsLocalDataSource settings = SettingsLocalDataSource(store);
  final List<_ScheduledReminder> scheduled = <_ScheduledReminder>[];
  final List<InAppNotificationEntity> inbox = <InAppNotificationEntity>[];
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];
  int scheduleCalls = 0;
  int cancelCalls = 0;
  bool pending = false;
  bool permission = true;
  Completer<bool>? permissionResult;
  Completer<void>? permissionRequested;
  DateTime now = DateTime.utc(2026, 11, 1, 10);

  late final TrialReminder reminder = TrialReminder(
    settings: () => settings,
    schedule: (DateTime at, String title, String body) async {
      scheduleCalls++;
      await scheduleOverride?.call(at, title, body);
      scheduled.add(_ScheduledReminder(at, title, body));
      pending = true;
    },
    cancel: () async {
      cancelCalls++;
      pending = false;
    },
    isScheduled: () async => pending,
    permissionGranted: () {
      if (permissionRequested != null && !permissionRequested!.isCompleted) permissionRequested!.complete();
      return permissionResult?.future ?? Future<bool>.value(permission);
    },
    postInbox: (InAppNotificationEntity item) async {
      if (postInboxOverride == null) {
        inbox.add(item);
      } else {
        await postInboxOverride!(item);
      }
    },
    track: events.add,
    localizations: () => AppLocalizations.delegate.load(const Locale('en')),
    storeName: 'App Store',
    now: () => now,
    isCurrentUser: isCurrentUser,
    isNotificationOwner: isNotificationOwner,
  );
}

EntitlementInfo _proEntitlement({
  required PeriodType periodType,
  required bool willRenew,
  String expiration = '2026-11-08T10:00:00Z',
}) {
  return EntitlementInfo(
    'prism_v3_pro_access',
    true,
    willRenew,
    '2026-11-01T10:00:00Z',
    '2026-11-01T10:00:00Z',
    'prism_pro_yearly',
    false,
    periodType: periodType,
    expirationDate: expiration,
  );
}

CustomerInfo _info({
  Map<String, EntitlementInfo> active = const <String, EntitlementInfo>{},
  Map<String, SubscriptionInfo> subscriptions = const <String, SubscriptionInfo>{},
}) {
  return CustomerInfo(
    EntitlementInfos(active, active),
    const <String, String?>{},
    const <String>[],
    const <String>[],
    const <StoreTransaction>[],
    '',
    'u1',
    const <String, String?>{},
    '',
    subscriptionsByProductIdentifier: subscriptions,
  );
}

CustomerInfo _trial({bool willRenew = true, String expiration = '2026-11-08T10:00:00Z'}) {
  return _info(
    active: <String, EntitlementInfo>{
      'prism_v3_pro_access': _proEntitlement(
        periodType: PeriodType.trial,
        willRenew: willRenew,
        expiration: expiration,
      ),
    },
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  test('schedules one reminder two days before the trial ends and tracks the start', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    h.now = DateTime.utc(2026, 11, 1, 10);

    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.scheduled, hasLength(1));
    expect(h.scheduled.single.at.isAtSameMomentAs(DateTime.utc(2026, 11, 6, 10)), isTrue);
    expect(h.scheduled.single.title, 'Your free trial ends on Nov 8, 2026');
    expect(
      h.scheduled.single.body,
      'After that, you pay for Prism Pro yearly. '
      'To avoid the charge, cancel in App Store settings at least 24 hours before.',
    );
    expect(h.events, hasLength(1));
    expect(h.events.single, isA<TrialStartedEvent>().having((e) => e.productId, 'productId', 'prism_pro_yearly'));
  });

  test('applying the same trial again schedules nothing and tracks nothing', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    await h.reminder.apply(_trial(), userId: 'u1');

    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.scheduled, hasLength(1));
    expect(h.events, hasLength(1));
  });

  test('concurrent applies schedule and track a trial only once', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    h.permissionResult = Completer<bool>();
    h.permissionRequested = Completer<void>();

    final Future<void> first = h.reminder.apply(_trial(), userId: 'u1');
    final Future<void> second = h.reminder.apply(_trial(), userId: 'u1');
    await h.permissionRequested!.future;
    h.permissionResult!.complete(true);
    await Future.wait(<Future<void>>[first, second]);

    expect(h.scheduleCalls, 1);
    expect(h.events.whereType<TrialStartedEvent>(), hasLength(1));
  });

  test('retries a failed native schedule on the next customer info update', () async {
    int failures = 1;
    final _Harness h = _Harness(
      scheduleOverride: (DateTime at, String title, String body) async {
        if (failures > 0) {
          failures--;
          throw StateError('schedule failed');
        }
      },
    );
    await h.reminder.setOptIn(true);

    await expectLater(h.reminder.apply(_trial(), userId: 'u1'), throwsA(isA<StateError>()));
    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.scheduled, hasLength(1));
    expect(h.events.whereType<TrialStartedEvent>(), hasLength(1));
  });

  test('moving the trial end reschedules the reminder', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    await h.reminder.apply(_trial(), userId: 'u1');

    await h.reminder.apply(
      _info(
        active: <String, EntitlementInfo>{
          'prism_v3_pro_access': _proEntitlement(
            periodType: PeriodType.trial,
            willRenew: true,
            expiration: '2026-11-09T10:00:00Z',
          ),
        },
      ),
      userId: 'u1',
    );

    expect(h.scheduled, hasLength(2));
    expect(h.scheduled.last.at.isAtSameMomentAs(DateTime.utc(2026, 11, 7, 10)), isTrue);
  });

  test('moving the trial end past the reminder time cancels the stale reminder', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    await h.reminder.apply(_trial(), userId: 'u1');
    h.now = DateTime.utc(2026, 11, 7, 10);

    await h.reminder.apply(
      _info(
        active: <String, EntitlementInfo>{
          'prism_v3_pro_access': _proEntitlement(
            periodType: PeriodType.trial,
            willRenew: true,
            expiration: '2026-11-09T10:00:00Z',
          ),
        },
      ),
      userId: 'u1',
    );

    expect(h.cancelCalls, 1);
    expect(h.pending, isFalse);
  });

  test('keeps the same pending reminder after its time because delivery can be late', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    await h.reminder.apply(_trial(), userId: 'u1');
    h.now = DateTime.utc(2026, 11, 7, 12);

    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.cancelCalls, 0);
    expect(h.pending, isTrue);
  });

  test('repairs a missing future notification instead of marking it delivered', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    await h.reminder.apply(_trial(), userId: 'u1');
    h.pending = false;

    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.scheduled, hasLength(2));
    expect(h.pending, isTrue);
  });

  test('a converted trial cancels the reminder and tracks conversion', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    await h.reminder.apply(_trial(), userId: 'u1');

    await h.reminder.apply(
      _info(
        active: <String, EntitlementInfo>{
          'prism_v3_pro_access': _proEntitlement(
            periodType: PeriodType.normal,
            willRenew: true,
            expiration: '2027-11-08T10:00:00Z',
          ),
        },
      ),
      userId: 'u1',
    );

    expect(h.cancelCalls, 1);
    expect(h.events, hasLength(2));
    expect(h.events.last, isA<TrialConvertedEvent>().having((e) => e.productId, 'productId', 'prism_pro_yearly'));
  });

  test('turning off auto-renew cancels the reminder and tracks the cancel', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    await h.reminder.apply(_trial(), userId: 'u1');

    await h.reminder.apply(_trial(willRenew: false), userId: 'u1');

    expect(h.cancelCalls, 1);
    expect(h.events.last, isA<TrialCancelledEvent>().having((e) => e.reason, 'reason', 'auto_renew_off'));
  });

  test('a refunded trial cancels the reminder and tracks the refund', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    await h.reminder.apply(_trial(), userId: 'u1');

    await h.reminder.apply(
      _info(
        subscriptions: <String, SubscriptionInfo>{
          'prism_pro_yearly': const SubscriptionInfo(
            'prism_pro_yearly',
            '2026-11-01T10:00:00Z',
            false,
            false,
            false,
            refundedAt: '2026-11-02T00:00:00Z',
          ),
        },
      ),
      userId: 'u1',
    );

    expect(h.cancelCalls, 1);
    expect(h.events.last, isA<TrialCancelledEvent>().having((e) => e.reason, 'reason', 'refunded'));
  });

  test('clear cancels a pending reminder even when its marker is missing without ending the trial', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    await h.reminder.apply(_trial(), userId: 'u1');
    await h.settings.delete('trialReminder');

    await h.reminder.clear();

    expect(h.cancelCalls, 1);
    expect(h.pending, isFalse);
    expect(h.events, hasLength(1));
    expect(h.events.single, isA<TrialStartedEvent>());
    expect(h.settings.get<String>('trialState.u1', defaultValue: ''), contains('prism_pro_yearly'));
  });

  test('clear keeps a pending reminder only for the matching resolved user', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    await h.reminder.apply(_trial(), userId: 'u1');

    await h.reminder.clear(keepUserId: 'u1');

    expect(h.cancelCalls, 0);
    expect(h.pending, isTrue);
    expect(h.settings.get<String>('trialReminder', defaultValue: ''), startsWith('u1|'));
  });

  test('clear preserves the per-end-date inbox delivery record', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    h.permission = false;
    h.now = DateTime.utc(2026, 11, 6, 12);
    await h.reminder.apply(_trial(), userId: 'u1');

    await h.reminder.clear();
    h.inbox.clear();
    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.inbox, isEmpty);
  });

  test('schedules nothing when the user opted out', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(false);

    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.scheduled, isEmpty);
  });

  test('without permission, posts one inbox item at the reminder time and not again', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    h.permission = false;
    h.now = DateTime.utc(2026, 11, 1, 10);

    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.scheduled, isEmpty);
    expect(h.inbox, isEmpty);

    h.now = DateTime.utc(2026, 11, 6, 12);
    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.scheduled, isEmpty);
    expect(h.inbox, hasLength(1));
    expect(h.inbox.single.id, 'local_trial_reminder_u1_1794132000000');
    expect(h.inbox.single.route, '/premium');
    expect(h.inbox.single.title, 'Your free trial ends on Nov 8, 2026');

    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.inbox, hasLength(1));
  });

  test('concurrent denied-permission applies post one inbox item', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    h.permission = false;
    h.now = DateTime.utc(2026, 11, 6, 12);
    h.permissionResult = Completer<bool>();
    h.permissionRequested = Completer<void>();

    final Future<void> first = h.reminder.apply(_trial(), userId: 'u1');
    final Future<void> second = h.reminder.apply(_trial(), userId: 'u1');
    await h.permissionRequested!.future;
    h.permissionResult!.complete(false);
    await Future.wait(<Future<void>>[first, second]);

    expect(h.inbox, hasLength(1));
    expect(h.events.whereType<TrialStartedEvent>(), hasLength(1));
  });

  test('retries a failed inbox write without recording delivery', () async {
    int failures = 1;
    int attempts = 0;
    final _Harness h = _Harness(
      postInboxOverride: (InAppNotificationEntity item) async {
        attempts++;
        if (failures > 0) {
          failures--;
          throw StateError('inbox write failed');
        }
      },
    );
    await h.reminder.setOptIn(true);
    h.permission = false;
    h.now = DateTime.utc(2026, 11, 6, 12);

    await expectLater(h.reminder.apply(_trial(), userId: 'u1'), throwsA(isA<StateError>()));
    await h.reminder.apply(_trial(), userId: 'u1');

    expect(attempts, 2);
    expect(h.settings.get<bool>('trialReminderDelivered.u1.1794132000000', defaultValue: false), isTrue);
  });

  test('posts inbox fallback when the OS no longer has the scheduled request', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    await h.reminder.apply(_trial(), userId: 'u1');
    h.pending = false;
    h.permission = false;
    h.now = DateTime.utc(2026, 11, 6, 12);

    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.inbox, hasLength(1));
  });

  test('a missing future notification is not marked delivered before fallback time', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    await h.reminder.apply(_trial(), userId: 'u1');
    h.pending = false;
    h.permission = false;
    h.now = DateTime.utc(2026, 11, 5, 12);

    await h.reminder.apply(_trial(), userId: 'u1');
    expect(h.inbox, isEmpty);

    h.now = DateTime.utc(2026, 11, 6, 12);
    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.inbox, hasLength(1));
  });

  test('a missing old native request does not suppress fallback for the new end date', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    await h.reminder.apply(_trial(), userId: 'u1');
    h.pending = false;
    h.permission = false;
    h.now = DateTime.utc(2026, 11, 7, 12);

    await h.reminder.apply(_trial(expiration: '2026-11-09T10:00:00Z'), userId: 'u1');

    expect(h.inbox, hasLength(1));
    expect(h.inbox.single.id, 'local_trial_reminder_u1_1794218400000');
  });

  test('A to B to A end-date changes do not post the same fallback twice', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    h.permission = false;
    h.now = DateTime.utc(2026, 11, 7, 12);

    await h.reminder.apply(_trial(), userId: 'u1');
    await h.reminder.apply(_trial(expiration: '2026-11-09T10:00:00Z'), userId: 'u1');
    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.inbox, hasLength(2));
    expect(h.inbox.map((InAppNotificationEntity item) => item.id).toSet(), hasLength(2));
  });

  test('clearing identity while permission is pending prevents the old trial posting an inbox item', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    h.permissionResult = Completer<bool>();
    h.permissionRequested = Completer<void>();
    h.now = DateTime.utc(2026, 11, 6, 12);

    final Future<void> apply = h.reminder.apply(_trial(), userId: 'u1');
    await h.permissionRequested!.future;
    final Future<void> clear = h.reminder.clear();
    h.permissionResult!.complete(false);
    await Future.wait(<Future<void>>[apply, clear]);

    expect(h.inbox, isEmpty);
    expect(h.cancelCalls, 1);
  });

  test('a stale signed-in user cannot post after identity changes while permission is pending', () async {
    bool current = true;
    final _Harness h = _Harness(isCurrentUser: (String userId) => current && userId == 'u1');
    await h.reminder.setOptIn(true);
    h.permissionResult = Completer<bool>();
    h.permissionRequested = Completer<void>();
    h.now = DateTime.utc(2026, 11, 6, 12);

    final Future<void> apply = h.reminder.apply(_trial(), userId: 'u1');
    await h.permissionRequested!.future;
    current = false;
    h.permissionResult!.complete(false);
    await apply;

    expect(h.inbox, isEmpty);
  });

  test('does not post or mark delivered when the inbox belongs to another user', () async {
    bool ownsInbox = false;
    final _Harness h = _Harness(isNotificationOwner: (String userId) => ownsInbox && userId == 'u1');
    await h.reminder.setOptIn(true);
    h.permission = false;
    h.now = DateTime.utc(2026, 11, 6, 12);

    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.inbox, isEmpty);
    expect(h.settings.get<bool>('trialReminderDelivered.u1.1794132000000', defaultValue: false), isFalse);

    ownsInbox = true;
    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.inbox, hasLength(1));
  });

  test('does not mark a silent stale-owner inbox write delivered', () async {
    final Directory directory = await Directory.systemTemp.createTemp('trial_reminder_owner_race');
    addTearDown(() => directory.delete(recursive: true));
    final NotificationsLocalDataSource notifications = NotificationsLocalDataSource.withStore(
      DurableJsonStore('trial_reminder_owner_race', directory: directory),
    )..setOwner('u1');
    bool switchOwnerDuringWrite = true;
    final _Harness h = _Harness(
      isNotificationOwner: (String userId) => notifications.ownerId == userId,
      postInboxOverride: (InAppNotificationEntity item) async {
        final Future<void> write = notifications.upsertAll(<InAppNotificationEntity>[item]);
        if (switchOwnerDuringWrite) {
          switchOwnerDuringWrite = false;
          notifications.setOwner('u2');
        }
        await write;
      },
    );
    await h.reminder.setOptIn(true);
    h.permission = false;
    h.now = DateTime.utc(2026, 11, 6, 12);

    await h.reminder.apply(_trial(), userId: 'u1');
    expect(h.settings.get<bool>('trialReminderDelivered.u1.1794132000000', defaultValue: false), isFalse);
    expect(await notifications.readAll(), isEmpty);

    notifications.setOwner('u1');
    h.now = DateTime.utc(2026, 11, 6, 13);
    await h.reminder.apply(_trial(), userId: 'u1');

    final List<InAppNotificationEntity> saved = await notifications.readAll();
    expect(saved, hasLength(1));
    expect(saved.single.createdAt, DateTime.utc(2026, 11, 6, 10));
    expect(h.settings.get<bool>('trialReminderDelivered.u1.1794132000000', defaultValue: false), isTrue);
  });

  test('inbox reconciliation preserves the user-scoped trial reminder', () async {
    final Directory directory = await Directory.systemTemp.createTemp('trial_reminder_test');
    addTearDown(() => directory.delete(recursive: true));
    final NotificationsLocalDataSource notifications = NotificationsLocalDataSource.withStore(
      DurableJsonStore('trial_reminder_inbox', directory: directory),
    )..setOwner('u1');
    final _Harness h = _Harness(
      postInboxOverride: (InAppNotificationEntity item) => notifications.upsertAll(<InAppNotificationEntity>[item]),
    );
    await h.reminder.setOptIn(true);
    h.permission = false;
    h.now = DateTime.utc(2026, 11, 6, 12);

    await h.reminder.apply(_trial(), userId: 'u1');
    await notifications.replaceAllPreservingReadState(
      const <InAppNotificationEntity>[],
      filterRemoved: (List<InAppNotificationEntity> items) async => items,
      isCurrentSession: () => true,
    );

    final List<InAppNotificationEntity> saved = await notifications.readAll();
    expect(saved, hasLength(1));
    expect(saved.single.id, startsWith('local_trial_reminder_u1_'));
  });

  test('schedules nothing when the reminder time has already passed', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    h.now = DateTime.utc(2026, 11, 7, 10);

    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.scheduled, isEmpty);
  });
}
