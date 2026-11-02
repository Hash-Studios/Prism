import 'dart:async';

import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
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

  setUp(() => TuningFeedView.precacheOverride = (_, _, _) async => true);
  tearDown(() => TuningFeedView.precacheOverride = null);

  List<FeedItemEntity> fourWalls() => <FeedItemEntity>[quizItem('a'), quizItem('b'), quizItem('c'), quizItem('d')];

  Widget tuning({List<FeedItemEntity>? walls, TasteSummary summary = const TasteSummary(), VoidCallback? onDone}) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TuningFeedView(walls: walls, summary: summary, onDone: onDone ?? () {}),
        ),
      );

  Future<void> pumpTuning(
    WidgetTester tester, {
    TasteSummary summary = const TasteSummary(),
    VoidCallback? onDone,
    bool loading = false,
  }) async {
    tester.view.physicalSize = const Size(600, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(tuning(walls: loading ? null : fourWalls(), summary: summary, onDone: onDone));
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

  testWidgets('while the walls load it shows the line and six placeholders and never finishes', (tester) async {
    int done = 0;
    await pumpTuning(tester, onDone: () => done++, loading: true);

    expect(find.text('Tuning your feed'), findsOneWidget);
    expect(find.text('Your feed is ready'), findsOneWidget);
    expect(find.byType(PulseFill), findsNWidgets(6));
    await tester.pump(const Duration(seconds: 5));
    expect(done, 0);
    expect(find.byType(PulseFill), findsNWidgets(6));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('walls that never load leave the line alone and finish after the hold', (tester) async {
    TuningFeedView.precacheOverride = (_, _, _) => Completer<bool>().future;
    int done = 0;
    await pumpTuning(tester, onDone: () => done++);

    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(PulseFill), findsNWidgets(6));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(PulseFill), findsNothing);
    expect(find.byType(PrismImageTile), findsNothing);
    expect(done, 0);

    await tester.pump(const Duration(milliseconds: 700));
    expect(done, 1);
  });

  testWidgets('fewer than four loaded walls show the line alone', (tester) async {
    int calls = 0;
    TuningFeedView.precacheOverride = (_, _, _) async => ++calls <= 3;
    int done = 0;
    await pumpTuning(tester, onDone: () => done++);
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.byType(PrismImageTile), findsNothing);
    await tester.pump(TuningFeedView.hold);
    expect(done, 1);
  });

  testWidgets('walls that arrive late hold for the full hold after they appear', (tester) async {
    int done = 0;
    await tester.pumpWidget(tuning(onDone: () => done++));
    await tester.pump(const Duration(milliseconds: 1000));

    await tester.pumpWidget(tuning(walls: fourWalls(), onDone: () => done++));
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.byType(PrismImageTile), findsNWidgets(4));

    await tester.pump(const Duration(milliseconds: 1000));
    expect(done, 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(done, 1);
  });

  testWidgets('empty walls finish after the hold with the line only', (tester) async {
    int done = 0;
    await tester.pumpWidget(tuning(onDone: () => done++));
    await tester.pumpWidget(tuning(walls: const <FeedItemEntity>[], onDone: () => done++));

    expect(find.byType(PulseFill), findsNothing);
    await tester.pump(TuningFeedView.hold);
    expect(done, 1);
  });
}
