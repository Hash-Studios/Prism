import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';
import 'package:Prism/features/taste_quiz/views/widgets/taste_quiz_view.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import 'taste_quiz_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TasteSignalStore store;
  late List<bool> finished;

  setUp(() {
    PrismHaptics.enabled = false;
    AnalyticsRuntime.instance = FakeAppAnalytics();
    store = TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore()));
    finished = <bool>[];
  });

  tearDown(() {
    AnalyticsRuntime.reset();
    PrismHaptics.enabled = true;
  });

  Future<void> pumpQuiz(WidgetTester tester, {TasteQuizPlan? plan}) async {
    tester.view.physicalSize = const Size(600, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TasteQuizView(
            plan: plan ?? quizPlan(),
            source: TasteQuizSource.onboarding,
            interests: const <String>['Nature'],
            tasteSignals: store,
            feed: quizFeed(),
            onFinished: (bool completed) => finished.add(completed),
          ),
        ),
      ),
    );
  }

  Finder leftPick() => find.bySemanticsLabel('Pick this wallpaper, 1 of 2');
  Finder rightPick() => find.bySemanticsLabel('Pick this wallpaper, 2 of 2');

  Future<void> pickLeft(WidgetTester tester) async {
    await tester.tap(leftPick());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  testWidgets('shows progress and both pick targets at the start', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpQuiz(tester);

    expect(find.text('1 of 6'), findsOneWidget);
    expect(find.bySemanticsLabel('Round 1 of 6'), findsOneWidget);
    expect(leftPick(), findsOneWidget);
    expect(rightPick(), findsOneWidget);
    expect(finished, isEmpty);
    handle.dispose();
  });

  testWidgets('picking a wall advances to the next round', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpQuiz(tester);

    await pickLeft(tester);

    expect(find.text('2 of 6'), findsOneWidget);
    expect(find.text('1 of 6'), findsNothing);
    handle.dispose();
  });

  testWidgets('wild card label shows on the third round only', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpQuiz(tester);

    expect(find.text('Wild card'), findsNothing);
    await pickLeft(tester);
    expect(find.text('Wild card'), findsNothing);
    await pickLeft(tester);

    expect(find.text('3 of 6'), findsOneWidget);
    expect(find.text('Wild card'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('skip ends the quiz as not completed and stores the picks', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpQuiz(tester);
    await pickLeft(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(finished, <bool>[false]);
    expect(store.read().length, 2);
    handle.dispose();
  });

  testWidgets('Skip exits from every round without loaded images', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    for (int round = 0; round < 6; round++) {
      await pumpQuiz(tester);
      for (int answered = 0; answered < round; answered++) {
        await tester.tap(leftPick());
        await tester.pump(const Duration(milliseconds: 220));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(finished, <bool>[false]);
      expect(store.read(), hasLength(round * 2));
      expect(find.text('Tuning your feed'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      finished.clear();
      store = TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore()));
    }
    handle.dispose();
  });

  testWidgets('a delayed pick after the quiz view is removed does not update the store', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await pumpQuiz(tester);

    await tester.tap(leftPick());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));

    expect(store.read(), isEmpty);
    expect(finished, isEmpty);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('full run shows tuning, then completes once after the hold', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpQuiz(tester);

    for (int i = 0; i < 6; i++) {
      await pickLeft(tester);
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Tuning your feed'), findsOneWidget);
    expect(find.text('Dark, minimal, a bit of neon'), findsOneWidget);
    expect(finished, isEmpty);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();

    expect(finished, <bool>[true]);
    handle.dispose();
  });

  testWidgets('reduced motion still advances after the short pick pause', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpQuiz(tester);

    await tester.tap(leftPick());
    // The 220 ms pick pause stays under reduced motion, so the next round waits for it.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('2 of 6'), findsOneWidget);
    await tester.pump(Duration.zero);
    handle.dispose();
  });

  testWidgets('a double tap on the same pair counts as one pick', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpQuiz(tester);

    await tester.tap(leftPick());
    await tester.tap(leftPick());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('2 of 6'), findsOneWidget);
    expect(find.text('3 of 6'), findsNothing);
    handle.dispose();
  });
}
