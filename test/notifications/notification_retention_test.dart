import 'dart:async';

import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/notifications/notification_retention.dart';
import 'package:Prism/notifications/notification_signals.dart';
import 'package:Prism/notifications/scoreboard_row.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_local_store.dart';

void main() {
  test('offset rounds to the 15 minute grid and stays in range', () {
    expect(roundedTimezoneOffsetMinutes(const Duration(minutes: 330)), 330);
    expect(roundedTimezoneOffsetMinutes(const Duration(minutes: 337)), 330);
    expect(roundedTimezoneOffsetMinutes(const Duration(minutes: 338)), 345);
    expect(roundedTimezoneOffsetMinutes(const Duration(minutes: -210)), -210);
    expect(roundedTimezoneOffsetMinutes(const Duration(hours: 20)), 840);
    expect(roundedTimezoneOffsetMinutes(const Duration(hours: -15)), -720);
    expect(roundedTimezoneOffsetMinutes(Duration.zero), 0);
  });

  test('app open stamp waits 15 minutes', () {
    final DateTime now = DateTime(2026, 10, 17, 18);
    expect(shouldStampAppOpen(now: now), isTrue);
    expect(shouldStampAppOpen(last: now.subtract(const Duration(minutes: 14)), now: now), isFalse);
    expect(shouldStampAppOpen(last: now.subtract(const Duration(minutes: 15)), now: now), isTrue);
  });

  test('next-day return credits the tap kinds once on the next local day', () {
    final PendingPushReturns pending = rememberTap(null, 'win_back', DateTime(2026, 10, 16, 18));
    final PendingPushReturns both = rememberTap(pending, 'wotd', DateTime(2026, 10, 16, 19));

    expect(returnsToReport(both, DateTime(2026, 10, 16, 23)), isEmpty);
    expect(returnsToReport(both, DateTime(2026, 10, 17, 0, 5)), <String>['win_back', 'wotd']);
    expect(returnsToReport(both, DateTime(2026, 10, 18, 9)), isEmpty);

    final PendingPushReturns reported = markReported(both, const <String>['wotd']);
    expect(returnsToReport(reported, DateTime(2026, 10, 17, 8)), <String>['win_back']);
  });

  test('a tap on the next day starts a new day after the return is taken', () {
    final PendingPushReturns yesterday = rememberTap(null, 'win_back', DateTime(2026, 10, 16, 18));
    expect(returnsToReport(yesterday, DateTime(2026, 10, 17, 9)), <String>['win_back']);
    final PendingPushReturns today = rememberTap(null, 'post', DateTime(2026, 10, 17, 9));
    expect(today.localDay, '2026-10-17');
    expect(today.kinds, <String>{'post'});
  });

  test('failed next-day return reporting keeps the old pending set', () {
    final PendingPushReturns yesterday = rememberTap(null, 'win_back', DateTime(2026, 10, 16, 18));
    final PendingPushReturns? failed = pendingAfterTapAttempt(
      current: yesterday,
      kind: 'wotd',
      now: DateTime(2026, 10, 17, 9),
      returnReportSucceeded: false,
    );
    expect(encodePending(failed!), encodePending(yesterday));

    final PendingPushReturns? succeeded = pendingAfterTapAttempt(
      current: yesterday,
      kind: 'wotd',
      now: DateTime(2026, 10, 17, 9),
      returnReportSucceeded: true,
    );
    expect(succeeded?.localDay, '2026-10-17');
    expect(succeeded?.kinds, <String>{'wotd'});
  });

  test('pending push memory survives a round trip and ignores a bad blob', () {
    final PendingPushReturns pending = rememberTap(
      rememberTap(null, 'campaign', DateTime(2026, 10, 1, 12)),
      'follower',
      DateTime(2026, 10, 1, 13),
    );
    final PendingPushReturns? decoded = decodePending(encodePending(markReported(pending, const <String>['campaign'])));
    expect(decoded?.localDay, '2026-10-01');
    expect(decoded?.kinds, <String>{'campaign', 'follower'});
    expect(decoded?.reported, <String>{'campaign'});
    expect(decodePending(''), isNull);
    expect(decodePending('{'), isNull);
  });

  test('onResumed still stamps app open and preserves pending returns when reporting fails', () async {
    final SettingsLocalDataSource store = await _signalSettings(<String, String>{
      PersistenceKeys.notificationSignalUserId: 'user-a',
      PersistenceKeys.pushReturnPending: encodePending(rememberTap(null, 'win_back', DateTime(2026, 10, 16, 18))),
    });
    final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];
    var stamps = 0;
    final NotificationSignals signals = NotificationSignals(
      isReady: () async => true,
      settings: store,
      currentUserId: () => 'user-a',
      clock: () => DateTime(2026, 10, 17, 9),
      call: (Map<String, dynamic> data) {
        calls.add(data);
        return Future<void>.error(StateError('offline'));
      },
      writeAppOpenStamp: (String _, DateTime _, int _) {
        stamps++;
        return Future<void>.value();
      },
    );

    await signals.onResumed();

    expect(calls.single, <String, dynamic>{'type': 'returned_next_day', 'kind': 'win_back'});
    expect(stamps, 1);
    expect(decodePending(store.get<String>(PersistenceKeys.pushReturnPending, defaultValue: ''))?.reported, isEmpty);
  });

  test('onTap keeps yesterday pending and still reports the current tap after return failure', () async {
    final SettingsLocalDataSource store = await _signalSettings(<String, String>{
      PersistenceKeys.notificationSignalUserId: 'user-a',
      PersistenceKeys.pushReturnPending: encodePending(rememberTap(null, 'win_back', DateTime(2026, 10, 16, 18))),
    });
    final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];
    final NotificationSignals signals = NotificationSignals(
      isReady: () async => true,
      settings: store,
      currentUserId: () => 'user-a',
      clock: () => DateTime(2026, 10, 17, 9),
      call: (Map<String, dynamic> data) {
        calls.add(data);
        if (data['type'] == 'returned_next_day') return Future<void>.error(StateError('offline'));
        return Future<void>.value();
      },
      writeAppOpenStamp: (String _, DateTime _, int _) => Future<void>.value(),
    );

    await signals.onTap('wotd');

    expect(calls, <Map<String, dynamic>>[
      <String, dynamic>{'type': 'returned_next_day', 'kind': 'win_back'},
      <String, dynamic>{'type': 'tap', 'kind': 'wotd'},
    ]);
    expect(decodePending(store.get<String>(PersistenceKeys.pushReturnPending, defaultValue: ''))?.kinds, <String>{
      'win_back',
    });
  });

  test('serialized resume and tap operations preserve the tap after an awaited return report', () async {
    final SettingsLocalDataSource store = await _signalSettings(<String, String>{
      PersistenceKeys.notificationSignalUserId: 'user-a',
      PersistenceKeys.pushReturnPending: encodePending(rememberTap(null, 'win_back', DateTime(2026, 10, 16, 18))),
    });
    final Completer<void> firstReportEntered = Completer<void>();
    final Completer<void> finishFirstReport = Completer<void>();
    var returnCalls = 0;
    final NotificationSignals signals = NotificationSignals(
      isReady: () async => true,
      settings: store,
      currentUserId: () => 'user-a',
      clock: () => DateTime(2026, 10, 17, 9),
      call: (Map<String, dynamic> data) async {
        if (data['type'] == 'returned_next_day' && returnCalls++ == 0) {
          firstReportEntered.complete();
          await finishFirstReport.future;
        }
      },
      writeAppOpenStamp: (String _, DateTime _, int _) => Future<void>.value(),
    );

    final Future<void> resume = signals.onResumed();
    await firstReportEntered.future;
    final Future<void> tap = signals.onTap('post');
    await Future<void>.delayed(Duration.zero);
    finishFirstReport.complete();
    await Future.wait(<Future<void>>[resume, tap]);

    final PendingPushReturns? pending = decodePending(
      store.get<String>(PersistenceKeys.pushReturnPending, defaultValue: ''),
    );
    expect(pending?.localDay, '2026-10-17');
    expect(pending?.kinds, <String>{'post'});
  });

  test('account switch clears the prior user debounce and stamps the new user', () async {
    final SettingsLocalDataSource store = await _signalSettings(<String, String>{
      PersistenceKeys.notificationSignalUserId: 'user-a',
      PersistenceKeys.appOpenStampedAtUtc: DateTime(2026, 10, 17, 8, 55).toIso8601String(),
      PersistenceKeys.pushReturnPending: encodePending(rememberTap(null, 'win_back', DateTime(2026, 10, 16, 18))),
    });
    final List<String> stampedUsers = <String>[];
    final NotificationSignals signals = NotificationSignals(
      isReady: () async => true,
      settings: store,
      currentUserId: () => 'user-b',
      clock: () => DateTime(2026, 10, 17, 9),
      call: (Map<String, dynamic> _) async {},
      writeAppOpenStamp: (String userId, DateTime _, int _) {
        stampedUsers.add(userId);
        return Future<void>.value();
      },
    );

    await signals.onResumed();

    expect(stampedUsers, <String>['user-b']);
    expect(store.get<String>(PersistenceKeys.notificationSignalUserId), 'user-b');
    expect(store.get<String>(PersistenceKeys.pushReturnPending, defaultValue: ''), isEmpty);
  });

  test('an account switch during a return report stops old-account calls and writes', () async {
    final SettingsLocalDataSource store = await _signalSettings(<String, String>{
      PersistenceKeys.notificationSignalUserId: 'user-a',
      PersistenceKeys.pushReturnPending: encodePending(
        rememberTap(rememberTap(null, 'win_back', DateTime(2026, 10, 16, 18)), 'wotd', DateTime(2026, 10, 16, 19)),
      ),
    });
    String currentUserId = 'user-a';
    final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];
    final NotificationSignals signals = NotificationSignals(
      isReady: () async => true,
      settings: store,
      currentUserId: () => currentUserId,
      clock: () => DateTime(2026, 10, 17, 9),
      call: (Map<String, dynamic> data) async {
        calls.add(data);
        currentUserId = 'user-b';
      },
      writeAppOpenStamp: (String _, DateTime _, int _) => Future<void>.value(),
    );

    await signals.onResumed();

    expect(calls, <Map<String, dynamic>>[
      <String, dynamic>{'type': 'returned_next_day', 'kind': 'win_back'},
    ]);
    expect(decodePending(store.get<String>(PersistenceKeys.pushReturnPending, defaultValue: ''))?.reported, isEmpty);
  });

  test('guest taps do not call the authenticated tap signal and permission uses install id', () async {
    final SettingsLocalDataSource store = await _signalSettings(<String, String>{});
    final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];
    final NotificationSignals signals = NotificationSignals(
      isReady: () async => true,
      settings: store,
      currentUserId: () => '',
      clock: () => DateTime(2026, 10, 17, 9),
      call: (Map<String, dynamic> data) {
        calls.add(data);
        return Future<void>.value();
      },
      writeAppOpenStamp: (String _, DateTime _, int _) => Future<void>.value(),
    );

    await signals.onTap('win_back');
    await signals.onPermission(true);

    expect(calls, hasLength(1));
    expect(calls.single['type'], 'permission');
    expect(calls.single['installId'], matches(RegExp(r'^[0-9a-f]{32}$')));
  });

  test('scoreboard line names sends, accepts, taps, and permission', () {
    final String line = formatScoreboardLine(
      ScoreboardDay.fromMap('2026-10-16', <String, dynamic>{
        'sends': <String, dynamic>{'win_back': 4, 'wotd': 2},
        'accepts': <String, dynamic>{'win_back': 3, 'wotd': 2},
        'fails': <String, dynamic>{'win_back': 1},
        'taps': <String, dynamic>{'win_back': 1},
        'returnedNextDay': <String, dynamic>{'wotd': 1},
        'permissionGranted': 5,
        'permissionDeclined': 2,
      }),
    );
    expect(
      line,
      '2026-10-16  win_back 4 sent, 3 accepted, 1 failed, 1 taps, 0 back · '
      'wotd 2 sent, 2 accepted, 0 failed, 0 taps, 1 back · permission 5 on, 2 off',
    );
    expect(formatScoreboardLine(const ScoreboardDay(day: '2026-10-15')), '2026-10-15');
  });
}

Future<SettingsLocalDataSource> _signalSettings(Map<String, String> initial) async {
  final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
  for (final MapEntry<String, String> entry in initial.entries) {
    await settings.set(entry.key, entry.value);
  }
  return settings;
}
