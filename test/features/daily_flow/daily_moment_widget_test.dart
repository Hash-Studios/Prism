import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:Prism/features/daily_flow/daily_moment_presentation_gate.dart';
import 'package:Prism/features/daily_flow/views/daily_moment_page.dart';
import 'package:Prism/features/rewards/views/widgets/daily_claim_host.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';
import '../../support/fake_daily_moment_repository.dart';
import '../../support/in_memory_local_store.dart';

void main() {
  setUp(() => AnalyticsRuntime.instance = FakeAppAnalytics());
  tearDown(AnalyticsRuntime.reset);

  Future<void> showMoment(WidgetTester tester, FakeDailyMomentRepository repository) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                useRootNavigator: true,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                builder: (_) =>
                    FractionallySizedBox(heightFactor: .82, child: DailyMomentContent(repository: repository)),
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('primary actions show streak, chest receipt, then free spin', (tester) async {
    final repository = FakeDailyMomentRepository();
    await showMoment(tester, repository);
    expect(find.text('Daily streak'), findsOneWidget);
    await tap(tester, 'Continue');
    expect(find.text('Daily chest'), findsOneWidget);
    await tap(tester, 'Open for 20 coins');
    expect(repository.calls, <String>['refresh', 'chest:20']);
    await tap(tester, 'Continue');
    expect(find.text('Free spin'), findsOneWidget);
    await tap(tester, 'Take free spin');
    expect(repository.calls, <String>['refresh', 'chest:20', 'refresh', 'spin:0']);
    await tap(tester, 'Continue');
    expect(find.text('Done'), findsOneWidget);
  });

  for (final step in DailyMomentStep.values) {
    testWidgets('closing at ${step.name} makes no later calls', (tester) async {
      final repository = FakeDailyMomentRepository();
      await showMoment(tester, repository);
      if (step != DailyMomentStep.streak) await tap(tester, 'Continue');
      if (step == DailyMomentStep.spin) {
        await tap(tester, 'Open for 20 coins');
        await tap(tester, 'Continue');
      }
      final before = List<String>.of(repository.calls);
      await tester.tap(find.byTooltip('Close daily moment'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Show'), findsOneWidget);
      expect(repository.calls, before);
      expect(repository.calls, isNot(contains('spin:0')));
      if (step == DailyMomentStep.streak) expect(repository.calls, isEmpty);
      if (step == DailyMomentStep.chest) expect(repository.calls, <String>['refresh']);
    });
  }
  testWidgets('host waits for startup, purchase, deep link and launch intents, and shows once per account', (
    tester,
  ) async {
    final backend = CoinsTestBackend();
    await backend.install();
    final store = InMemoryLocalStore();
    PersistenceRuntime.store = store;
    DailyMomentConfig.enabledOverride = true;
    final gate = DailyMomentPresentationGate.instance;
    gate.launchIntentsReady = false;
    gate.bootstrapReady = false;
    gate.purchaseActive = true;
    gate.deepLinkActive = true;
    addTearDown(() async {
      gate.launchIntentsReady = false;
      gate.bootstrapReady = false;
      gate.purchaseActive = false;
      gate.deepLinkActive = false;
      DailyMomentConfig.enabledOverride = null;
      app_state.prismUser = app_constants.createGuestPrismUser();
      await getIt.reset();
    });
    Widget host() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DailyClaimSheetHost(
        onSeeRewards: () {},
        child: const Scaffold(body: Text('Home')),
      ),
    );
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.byTooltip('Close daily moment'), findsNothing);
    gate.bootstrapReady = true;
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('Close daily moment'), findsNothing);
    gate.purchaseActive = false;
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('Close daily moment'), findsNothing);
    gate.deepLinkActive = false;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byTooltip('Close daily moment'), findsNothing);
    expect(store.get('dailyMoment.shown.${backend.userId}'), isNull);
    gate.launchIntentsReady = true;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byTooltip('Close daily moment'), findsOneWidget);
    expect(store.get('dailyMoment.shown.${backend.userId}'), isNotNull);
    await tester.tap(find.byTooltip('Close daily moment'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byTooltip('Close daily moment'), findsNothing);
    app_state.prismUser.id = '${backend.userId}-other';
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byTooltip('Close daily moment'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
