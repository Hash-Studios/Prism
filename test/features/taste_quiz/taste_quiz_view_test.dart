import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';
import 'package:Prism/features/taste_quiz/domain/taste_quiz_rules.dart';
import 'package:Prism/features/taste_quiz/views/widgets/taste_quiz_view.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import 'taste_quiz_fixtures.dart';

class _QuizImageCache extends Mock implements BaseCacheManager {}

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

  testWidgets('a measured final-round wall updates tuning after the rounds unmount', (tester) async {
    final TasteQuizPlan plan = TasteQuizPlan(
      rounds: <QuizRound>[
        for (int index = 0; index < 6; index++)
          QuizRound(
            left: quizWall('late_l$index', wildCard: index == 2, tags: const <String>['dark', 'minimal', 'neon']),
            right: quizWall('late_r$index', wildCard: index == 2, tags: const <String>['bright', 'city', 'beach']),
          ),
      ],
    );
    final _QuizImageCache cache = _QuizImageCache();
    final BaseCacheManager? previousThumbnailCache = PrismImageCache.testOverride;
    final BaseCacheManager? previousFullCache = PrismFullImageCache.testOverride;
    PrismImageCache.testOverride = cache;
    PrismFullImageCache.testOverride = cache;
    addTearDown(() {
      PrismImageCache.testOverride = previousThumbnailCache;
      PrismFullImageCache.testOverride = previousFullCache;
    });

    final Map<String, Completer<WallLook?>> delayedLooks = <String, Completer<WallLook?>>{
      for (final int index in <int>[0, 3, 4, 5]) 'https://example.com/thumb_late_l$index.jpg': Completer<WallLook?>(),
    };
    when(
      () => cache.getFileStream(
        any(),
        key: any(named: 'key'),
        headers: any(named: 'headers'),
        withProgress: true,
      ),
    ).thenAnswer((invocation) {
      return Stream<FileResponse>.error(StateError('preview unavailable'));
    });
    TasteQuizView.measureLookOverride = (url) =>
        delayedLooks[url]?.future ?? Future<WallLook?>.value(const WallLook(luma: 0.9, edges: 0.02));
    addTearDown(() => TasteQuizView.measureLookOverride = null);

    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpQuiz(tester, plan: plan);
    await tester.idle();
    for (int round = 0; round < 6; round++) {
      expect(find.text('${round + 1} of 6'), findsOneWidget);
      await tester.tapAt(tester.getCenter(leftPick()));
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();
      await tester.idle();
      if (round < 5) expect(find.text('${round + 2} of 6'), findsOneWidget);
    }

    expect(find.text('Tuning your feed'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('6 of 6'), findsNothing);

    for (final int index in <int>[3, 4, 5]) {
      delayedLooks['https://example.com/thumb_late_l$index.jpg']!.complete(const WallLook(luma: 0.9, edges: 0.02));
    }
    await tester.idle();
    await tester.pump();

    expect(find.text('Light, minimal, a bit of neon'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    delayedLooks['https://example.com/thumb_late_l0.jpg']!.complete(const WallLook(luma: 0.9, edges: 0.02));
    await tester.idle();
    await tester.pump();
    expect(tester.takeException(), isNull);
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
