import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';
import 'package:Prism/features/taste_quiz/domain/taste_quiz_rules.dart';
import 'package:Prism/features/taste_quiz/views/widgets/tuning_feed_view.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'taste_quiz_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpTuning(
    WidgetTester tester, {
    TasteSummary summary = const TasteSummary(),
    VoidCallback? onDone,
  }) async {
    tester.view.physicalSize = const Size(600, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TuningFeedView(
            walls: <FeedItemEntity>[quizItem('a'), quizItem('b'), quizItem('c'), quizItem('d')],
            summary: summary,
            onDone: onDone ?? () {},
          ),
        ),
      ),
    );
  }

  group('tasteSummaryLine', () {
    final AppLocalizations l10n = AppLocalizationsEn();

    test('tone, density and tag', () {
      expect(
        tasteSummaryLine(const TasteSummary(tone: QuizTone.dark, density: QuizDensity.minimal, tag: 'neon'), l10n),
        'Dark, minimal, a bit of neon',
      );
    });

    test('tone and density', () {
      expect(
        tasteSummaryLine(const TasteSummary(tone: QuizTone.light, density: QuizDensity.busy), l10n),
        'Light and detailed',
      );
    });

    test('tone and tag', () {
      expect(tasteSummaryLine(const TasteSummary(tone: QuizTone.dark, tag: 'neon'), l10n), 'Dark, with a bit of neon');
    });

    test('density and tag', () {
      expect(
        tasteSummaryLine(const TasteSummary(density: QuizDensity.minimal, tag: 'space'), l10n),
        'Minimal, with a bit of space',
      );
    });

    test('tone only', () {
      expect(tasteSummaryLine(const TasteSummary(tone: QuizTone.dark), l10n), 'Mostly dark walls');
    });

    test('density only', () {
      expect(tasteSummaryLine(const TasteSummary(density: QuizDensity.busy), l10n), 'Mostly detailed walls');
    });

    test('tag only', () {
      expect(tasteSummaryLine(const TasteSummary(tag: 'neon'), l10n), 'More neon walls');
    });

    test('empty summary', () {
      expect(tasteSummaryLine(const TasteSummary(), l10n), 'Your feed is ready');
    });
  });

  testWidgets('shows the title and the ready line for an empty summary', (tester) async {
    await pumpTuning(tester);

    expect(find.text('Tuning your feed'), findsOneWidget);
    expect(find.text('Your feed is ready'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the summary line is a live region', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpTuning(tester);

    final Finder liveRegion = find.byWidgetPredicate((Widget w) => w is Semantics && w.properties.liveRegion == true);
    expect(find.descendant(of: liveRegion, matching: find.text('Your feed is ready')), findsOneWidget);
    handle.dispose();

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('onDone fires once after the hold, not before', (tester) async {
    int done = 0;
    await pumpTuning(tester, onDone: () => done++);

    await tester.pump(const Duration(milliseconds: 1400));
    expect(done, 0);

    await tester.pump(const Duration(milliseconds: 200));
    expect(done, 1);

    await tester.pump(const Duration(seconds: 2));
    expect(done, 1);
  });

  testWidgets('onDone does not fire when the view is removed before the hold ends', (tester) async {
    int done = 0;
    await pumpTuning(tester, onDone: () => done++);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));

    expect(done, 0);
  });
}
