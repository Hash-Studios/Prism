import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/features/rewards/views/widgets/daily_claim_sheet.dart';
import 'package:Prism/features/streak/data/streak_rescue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';

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

class _FakeRescue extends StreakRescueService {
  _FakeRescue(this.result) : super(call: (_) async => <String, dynamic>{});

  final StreakRescueResult result;
  int restores = 0;

  @override
  Future<StreakRescueResult> restore() async {
    restores++;
    return result;
  }
}

void main() {
  late FakeAppAnalytics analytics;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    CoinsService.instance.balanceNotifier.value = 250;
  });

  tearDown(() {
    AnalyticsRuntime.reset();
    CoinsService.instance.balanceNotifier.value = 0;
  });

  Future<void> open(
    WidgetTester tester,
    StreakClaimResult claim,
    StreakRescueService rescue, {
    VoidCallback? onSeeRewards,
    VoidCallback? onEarnCoins,
  }) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDailyClaimSheet(
                context,
                claim,
                rescueService: rescue,
                onSeeRewards: onSeeRewards,
                onEarnCoins: onEarnCoins,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  GlintMood mood(WidgetTester tester) => tester.widget<Glint>(find.byType(Glint)).mood;

  testWidgets('a broken 9-day streak offers a 100 coin restore and logs the offer', (tester) async {
    await open(tester, _claim(), _FakeRescue(const StreakRescueResult(StreakRescueOutcome.restored)));

    expect(find.text('Restore your 9-day streak · 100 coins'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('Get a freeze for next time'), findsOneWidget);
    expect(mood(tester), GlintMood.sad);
    expect(analytics.events.whereType<StreakRescueOfferedEvent>().single.streakCount, 9);
  });

  testWidgets('a short break or a normal claim shows no restore', (tester) async {
    await open(tester, _claim(previous: 6), _FakeRescue(const StreakRescueResult(StreakRescueOutcome.restored)));
    expect(find.text('Restore'), findsNothing);
    expect(find.textContaining('Restore your'), findsNothing);
    expect(analytics.events.whereType<StreakRescueOfferedEvent>(), isEmpty);
  });

  testWidgets('Restore buys the streak and Glint celebrates', (tester) async {
    final rescue = _FakeRescue(const StreakRescueResult(StreakRescueOutcome.restored, streakCount: 10));
    await open(tester, _claim(), rescue);

    await tester.tap(find.text('Restore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(rescue.restores, 1);
    expect(find.text('Your streak is back'), findsOneWidget);
    expect(find.text('You are on 10 days again.'), findsOneWidget);
    expect(find.text('Restore'), findsNothing);
    expect(find.text('Nice'), findsOneWidget);
    expect(mood(tester), GlintMood.celebrate);
  });

  testWidgets('a low balance routes to Earn coins without calling the server', (tester) async {
    CoinsService.instance.balanceNotifier.value = 40;
    final rescue = _FakeRescue(const StreakRescueResult(StreakRescueOutcome.restored));
    int earn = 0;
    int rewards = 0;
    await open(tester, _claim(), rescue, onEarnCoins: () => earn++, onSeeRewards: () => rewards++);

    expect(find.text('You have 40. You need 100.'), findsOneWidget);
    await tester.tap(find.text('Earn coins'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(rescue.restores, 0);
    expect(earn, 1);
    expect(rewards, 0);
    expect(find.text('Earn coins'), findsNothing);
  });

  testWidgets('a refusal hides the offer and keeps the sheet', (tester) async {
    final rescue = _FakeRescue(
      const StreakRescueResult(StreakRescueOutcome.unavailable, reason: 'streak_rescue_cooldown'),
    );
    await open(tester, _claim(), rescue);

    await tester.tap(find.text('Restore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Restore'), findsNothing);
    expect(find.text('Your streak reset'), findsOneWidget);
    expect(mood(tester), GlintMood.sad);
  });

  testWidgets('a failed call keeps the offer so the user can try again', (tester) async {
    final rescue = _FakeRescue(const StreakRescueResult(StreakRescueOutcome.failed));
    await open(tester, _claim(), rescue);

    await tester.tap(find.text('Restore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Restore'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await tester.pump();
    expect(rescue.restores, 2);
  });
}
