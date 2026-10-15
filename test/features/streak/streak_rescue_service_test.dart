import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/streak/data/streak_rescue_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

StreakClaimResult _claim({bool broken = true, int previous = 9}) => StreakClaimResult(
  claimed: true,
  alreadyClaimedToday: false,
  streakDay: 1,
  streakCount: 1,
  previousStreakCount: previous,
  streakBest: previous,
  streakBroken: broken,
  freezesUsed: 0,
  freezesLeft: 0,
  isWeekComplete: false,
  dailyReward: 5,
  streakBonusReward: 0,
  proBonusReward: 0,
  totalReward: 5,
  newBalance: 200,
);

void main() {
  late FakeAppAnalytics analytics;
  late SettingsLocalDataSource settings;
  late List<Map<String, dynamic>> calls;
  late int refreshes;
  late int ids;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    calls = <Map<String, dynamic>>[];
    refreshes = 0;
    ids = 0;
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
  });

  tearDown(() {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  StreakRescueService service(Future<Map<String, dynamic>> Function(Map<String, dynamic> data) call) =>
      StreakRescueService(
        call: (data) {
          calls.add(data);
          return call(data);
        },
        settings: settings,
        newRequestId: () => 'request-${++ids}-abcdefgh',
        refreshBalance: () async => refreshes++,
      );

  group('offer', () {
    test('a broken streak of 7 days or more is offered', () {
      expect(StreakRescueOffer.fromClaim(_claim())?.count, 9);
      expect(StreakRescueOffer.fromClaim(_claim(previous: 7))?.count, 7);
    });

    test('a short break or an unbroken streak is not offered', () {
      expect(StreakRescueOffer.fromClaim(_claim(previous: 6)), isNull);
      expect(StreakRescueOffer.fromClaim(_claim(broken: false)), isNull);
    });
  });

  group('restore', () {
    test('success refreshes the balance and reports the streak', () async {
      final result = await service(
        (_) async => <String, dynamic>{'success': true, 'streakCount': 10, 'currentBalance': 100},
      ).restore();

      expect(result.outcome, StreakRescueOutcome.restored);
      expect(result.streakCount, 10);
      expect(refreshes, 1);
      expect(calls.single, <String, dynamic>{'requestId': 'request-1-abcdefgh'});
      expect(analytics.events.whereType<StreakRescueUsedEvent>().single.result, 'restored');
    });

    test('a retry after a failed call reuses the request id, a new buy gets a new one', () async {
      bool fail = true;
      final svc = service((_) async {
        if (fail) throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
        return <String, dynamic>{'success': true, 'streakCount': 10};
      });

      expect((await svc.restore()).outcome, StreakRescueOutcome.failed);
      fail = false;
      expect((await svc.restore()).outcome, StreakRescueOutcome.restored);
      expect(calls.map((c) => c['requestId']).toSet(), <String>{'request-1-abcdefgh'});

      await svc.restore();
      expect(calls.last['requestId'], 'request-2-abcdefgh');
      expect(analytics.events.whereType<StreakRescueUsedEvent>().map((e) => e.result), <String>[
        'failed',
        'restored',
        'restored',
      ]);
    });

    test('a low balance reply maps to insufficientBalance and clears the request id', () async {
      final svc = service(
        (_) async => <String, dynamic>{
          'success': false,
          'insufficientBalance': true,
          'reason': 'streak_rescue_insufficient_balance',
        },
      );

      expect((await svc.restore()).outcome, StreakRescueOutcome.insufficientBalance);
      await svc.restore();
      expect(calls.map((c) => c['requestId']), <String>['request-1-abcdefgh', 'request-2-abcdefgh']);
      expect(refreshes, 0);
    });

    test('a refusal maps to unavailable with the server reason', () async {
      final result = await service(
        (_) async => <String, dynamic>{'success': false, 'reason': 'streak_rescue_cooldown'},
      ).restore();

      expect(result.outcome, StreakRescueOutcome.unavailable);
      expect(result.reason, 'streak_rescue_cooldown');
      expect(analytics.events.whereType<StreakRescueUsedEvent>().single.result, 'unavailable');
    });

    test('a signed-out user never calls the server', () async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      final result = await service((_) async => <String, dynamic>{'success': true}).restore();

      expect(result.outcome, StreakRescueOutcome.failed);
      expect(calls, isEmpty);
    });
  });
}
