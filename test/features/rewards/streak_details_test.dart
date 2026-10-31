import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/rewards/views/widgets/streak_details.dart';
import 'package:Prism/features/streak/data/streak_rescue_service.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

class _Rescue extends StreakRescueService {
  int restores = 0;

  @override
  Future<StreakRescueOffer?> fetch() async => const StreakRescueOffer(9);

  @override
  Future<StreakRescueResult> restore() async {
    restores++;
    return const StreakRescueResult(StreakRescueOutcome.restored, streakCount: 10);
  }
}

void main() {
  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    CoinsService.instance.balanceNotifier.value = kStreakRescueCost;
  });
  tearDown(() {
    AnalyticsRuntime.reset();
    CoinsService.instance.balanceNotifier.value = 0;
  });

  testWidgets('details fetches a rescue and displays the server restored count', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final rescue = _Rescue();
    final l10n = AppLocalizationsEn();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPrismSheet<void>(context, builder: (_) => StreakDetails(rescueService: rescue)),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.economyRestoreStreak(9, kStreakRescueCost)), findsOneWidget);
    await tester.tap(find.text(l10n.economyRestore));
    await tester.pumpAndSettle();
    expect(rescue.restores, 1);
    expect(find.text(l10n.economyStreakRestoredCount(10)), findsOneWidget);
    expect(find.text(l10n.economyRestore), findsNothing);
  });
}
