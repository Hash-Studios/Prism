import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';
import 'package:Prism/features/taste_quiz/domain/taste_quiz_rules.dart';
import 'package:Prism/features/taste_quiz/views/widgets/taste_quiz_view.dart';
import 'package:Prism/features/taste_quiz/views/widgets/tuning_feed_view.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import 'taste_quiz_fixtures.dart';

const Map<String, Size> _screens = <String, Size>{
  'small phone': Size(320, 568),
  'phone': Size(393, 852),
  'tablet portrait': Size(1024, 1366),
  'tablet landscape': Size(1366, 1024),
};

void main() {
  setUp(() {
    PrismHaptics.enabled = false;
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() {
    AnalyticsRuntime.reset();
    PrismHaptics.enabled = true;
  });

  Future<void> pump(WidgetTester tester, Size size, double textScale, Widget child) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: app!,
        ),
        home: Scaffold(body: child),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  for (final MapEntry<String, Size> screen in _screens.entries) {
    for (final double textScale in <double>[1, 1.6]) {
      testWidgets('rounds fit on a ${screen.key} at text scale $textScale', (tester) async {
        await pump(
          tester,
          screen.value,
          textScale,
          TasteQuizView(
            plan: quizPlan(),
            source: TasteQuizSource.onboarding,
            interests: const <String>['Nature'],
            tasteSignals: TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())),
            onFinished: (_) {},
          ),
        );

        expect(tester.takeException(), isNull);
        final Size left = tester.getSize(find.bySemanticsLabel('Pick this wallpaper, 1 of 2'));
        expect(left.height, greaterThan(left.width));
      });

      testWidgets('tuning walls fit on a ${screen.key} at text scale $textScale', (tester) async {
        await pump(
          tester,
          screen.value,
          textScale,
          TuningFeedView(
            walls: <String>['a', 'b', 'c', 'd', 'e', 'f'].map(quizItem).toList(),
            summary: const TasteSummary(tone: QuizTone.dark, density: QuizDensity.minimal, tag: 'neon'),
            onDone: () {},
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Dark, minimal, a bit of neon'), findsOneWidget);
        await tester.pump(TuningFeedView.hold);
      });
    }
  }
}
