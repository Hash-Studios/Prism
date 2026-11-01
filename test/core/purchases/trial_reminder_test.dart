import 'package:Prism/core/analytics/events/events.dart';
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
  final InMemoryLocalStore store = InMemoryLocalStore();
  late final SettingsLocalDataSource settings = SettingsLocalDataSource(store);
  final List<_ScheduledReminder> scheduled = <_ScheduledReminder>[];
  final List<InAppNotificationEntity> inbox = <InAppNotificationEntity>[];
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];
  int cancelCalls = 0;
  bool pending = false;
  bool permission = true;
  DateTime now = DateTime.utc(2026, 11, 1, 10);

  late final TrialReminder reminder = TrialReminder(
    settings: () => settings,
    schedule: (DateTime at, String title, String body) async {
      scheduled.add(_ScheduledReminder(at, title, body));
      pending = true;
    },
    cancel: () async {
      cancelCalls++;
      pending = false;
    },
    isScheduled: () async => pending,
    permissionGranted: () async => permission,
    postInbox: (InAppNotificationEntity item) async => inbox.add(item),
    track: events.add,
    localizations: () => AppLocalizations.delegate.load(const Locale('en')),
    storeName: 'App Store',
    now: () => now,
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

CustomerInfo _trial({bool willRenew = true}) {
  return _info(
    active: <String, EntitlementInfo>{
      'prism_v3_pro_access': _proEntitlement(periodType: PeriodType.trial, willRenew: willRenew),
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
    expect(h.inbox.single.id, 'trial_reminder_1794132000000');
    expect(h.inbox.single.route, '/premium');
    expect(h.inbox.single.title, 'Your free trial ends on Nov 8, 2026');

    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.inbox, hasLength(1));
  });

  test('schedules nothing when the reminder time has already passed', () async {
    final _Harness h = _Harness();
    await h.reminder.setOptIn(true);
    h.now = DateTime.utc(2026, 11, 7, 10);

    await h.reminder.apply(_trial(), userId: 'u1');

    expect(h.scheduled, isEmpty);
  });
}
