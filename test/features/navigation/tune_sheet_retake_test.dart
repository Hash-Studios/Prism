import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/features/personalized_feed/domain/entities/feed_mix.dart';
import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';
import 'package:Prism/features/taste_quiz/domain/repositories/taste_quiz_repository.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import '../taste_quiz/taste_quiz_fixtures.dart';

class _RecordingAnalytics extends FakeAppAnalytics {
  final List<String> names = <String>[];

  @override
  Future<void> track(AnalyticsEvent event) async {
    names.add(event.eventName);
    await super.track(event);
  }
}

class _FakeTasteQuizRepository implements TasteQuizRepository {
  TasteQuizPlan? plan;
  List<List<String>> calls = <List<String>>[];

  @override
  Future<TasteQuizPlan?> loadPlan(List<String> interests) async {
    calls.add(interests);
    return plan;
  }
}

final List<PersonalizedInterest> _catalog = <PersonalizedInterest>[
  for (final String name in <String>['Nature', 'Abstract', 'Space', 'Minimal', 'Cars'])
    PersonalizedInterest(name: name, query: name, imageUrl: '', sources: const <WallpaperSource>[]),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TasteSignalStore store;
  late _FakeTasteQuizRepository repo;
  late _RecordingAnalytics analytics;
  late List<TasteQuizPlan> opened;

  setUp(() {
    PrismHaptics.enabled = false;
    personalizedFeedSettingsRevision.value = 0;
    store = TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore()));
    repo = _FakeTasteQuizRepository();
    analytics = _RecordingAnalytics();
    AnalyticsRuntime.instance = analytics;
    opened = <TasteQuizPlan>[];
  });

  tearDown(() {
    toasts.overlayResolver = null;
    AnalyticsRuntime.reset();
    PrismHaptics.enabled = true;
  });

  void showToastsInTree(WidgetTester tester) {
    toasts.overlayResolver = () => tester.state<OverlayState>(find.byType(Overlay).first);
  }

  Future<void> pumpSheet(
    WidgetTester tester, {
    Future<bool?> Function(BuildContext, {required TasteQuizPlan plan, required List<String> interests})? openRetake,
  }) async {
    tester.view.physicalSize = const Size(600, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () => showPrismSheet<void>(
                context,
                detents: const <PrismSheetDetent>[PrismSheetDetent.large],
                builder: (_) => PersonalizedFeedSettingsSheet(
                  catalog: _catalog,
                  initialInterests: const <String>{'Nature', 'Abstract', 'Space'},
                  initialFeedMix: FeedMix.balanced,
                  onSave: (_, _) async => true,
                  tasteSignals: store,
                  tasteQuiz: repo,
                  openRetake:
                      openRetake ??
                      (BuildContext context, {required TasteQuizPlan plan, required List<String> interests}) async {
                        opened.add(plan);
                        return true;
                      },
                ),
              ),
              child: const Text('Open sheet'),
            ),
          ),
        ),
      ),
    );
    showToastsInTree(tester);
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
  }

  Future<void> tapRetake(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Retake This or that'));
    await tester.tap(find.text('Retake This or that'));
    await tester.pumpAndSettle();
  }

  testWidgets('the retake button is shown', (tester) async {
    await pumpSheet(tester);

    expect(find.text('Retake This or that'), findsOneWidget);
  });

  testWidgets('retake loads the plan for the selected interests and opens the quiz with it', (tester) async {
    repo.plan = quizPlan();
    await pumpSheet(tester);

    await tapRetake(tester);

    expect(repo.calls, hasLength(1));
    expect(repo.calls.single, unorderedEquals(<String>['Nature', 'Abstract', 'Space']));
    expect(opened, hasLength(1));
    expect(opened.single, same(repo.plan));
    expect(analytics.names, contains('taste_quiz_retake_opened'));
  });

  testWidgets('retake with no plan shows an error and does not open the quiz', (tester) async {
    repo.plan = null;
    await pumpSheet(tester);

    await tapRetake(tester);

    expect(repo.calls, hasLength(1));
    expect(opened, isEmpty);
    expect(find.text("Couldn't load walls. Check your connection and try again."), findsOneWidget);
  });

  testWidgets('learned terms refresh after the quiz returns', (tester) async {
    repo.plan = quizPlan();
    await pumpSheet(
      tester,
      openRetake: (BuildContext context, {required TasteQuizPlan plan, required List<String> interests}) async {
        await store.record(
          TasteSignal(action: TasteAction.favourite, at: DateTime.now(), terms: const <String>['neon']),
        );
        return true;
      },
    );
    expect(find.text('Open, save and set walls to teach your feed.'), findsOneWidget);
    expect(find.text('Neon'), findsNothing);

    await tapRetake(tester);

    expect(find.text('Neon'), findsOneWidget);
  });
}
