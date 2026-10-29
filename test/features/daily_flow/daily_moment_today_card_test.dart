import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/daily_flow/views/daily_moment_today_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../quests/fake_quests_repository.dart';

void main() {
  tearDown(() {
    CoinsService.instance.balanceNotifier.value = 0;
    CoinsService.instance.questsNotifier.value = null;
    CoinsService.instance.streakNotifier.value = StreakStatus.empty;
  });

  Future<void> pumpCard(WidgetTester tester, {double scale = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const Scaffold(body: SingleChildScrollView(child: DailyMomentTodayCard())),
      ),
    );
    await tester.pump();
  }

  testWidgets('Today updates the actual balance and available chest', (tester) async {
    CoinsService.instance.balanceNotifier.value = 137;
    CoinsService.instance.questsNotifier.value = questState();
    await pumpCard(tester);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Balance: 137 coins'), findsOneWidget);
    expect(find.text('Daily chest available'), findsOneWidget);
    expect(find.text('Continue daily moment'), findsOneWidget);
    CoinsService.instance.balanceNotifier.value = 91;
    await tester.pump();
    expect(find.text('Balance: 91 coins'), findsOneWidget);
  });

  testWidgets('Today keeps a claim entry when the streak has not been claimed', (tester) async {
    CoinsService.instance.streakNotifier.value = StreakStatus.empty;
    CoinsService.instance.questsNotifier.value = questState(chestOpened: true);
    await pumpCard(tester);
    expect(find.text('Continue daily moment'), findsOneWidget);
    expect(find.text('Daily streak available'), findsOneWidget);
  });

  testWidgets('Today removes the streak receipt as soon as the moment consumes it', (tester) async {
    final backend = CoinsTestBackend();
    await backend.install();
    addTearDown(() async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      await getIt.reset();
    });
    backend.onCall = (_, _) async => <String, Object>{
      ...CoinsTestBackend.claimPayload,
      'todayLocalKey': DateTime.now().toUtc().toIso8601String().substring(0, 10),
      'timezoneOffsetMinutes': 0,
    };
    await CoinsService.instance.claimDailyLoginAndStreakIfEligible();
    CoinsService.instance.questsNotifier.value = questState(chestOpened: true);
    await pumpCard(tester);
    expect(find.text('Daily streak available'), findsOneWidget);
    CoinsService.instance.consumeLastClaim();
    await tester.pump();
    expect(find.text('Daily streak available'), findsNothing);
    expect(find.text('Continue daily moment'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Today fits a narrow screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    CoinsService.instance.questsNotifier.value = questState();
    await pumpCard(tester, scale: 2.4);
    expect(tester.takeException(), isNull);
  });
}
