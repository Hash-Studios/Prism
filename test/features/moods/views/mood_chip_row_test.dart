import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/widgets/prism/prism_chip.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/views/widgets/mood_chip_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';

void main() {
  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(AnalyticsRuntime.reset);

  testWidgets('shows one chip per mood with its localized title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MoodChipRow(
            moods: <MoodList>[
              MoodList(mood: WallMood.dreamy, wallIds: <String>[]),
              MoodList(mood: WallMood.darkQuiet, wallIds: <String>[]),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(PrismChip), findsNWidgets(2));
    expect(find.text('Dreamy'), findsOneWidget);
    expect(find.text('Dark and quiet'), findsOneWidget);
  });

  testWidgets('renders no chip for an empty mood list', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MoodChipRow(moods: <MoodList>[])),
      ),
    );

    expect(find.byType(PrismChip), findsNothing);
  });

  testWidgets('the row is labelled Moods for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MoodChipRow(
            moods: <MoodList>[MoodList(mood: WallMood.dreamy, wallIds: <String>[])],
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Moods'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('mood chips are compact pills with a 44 pt tap target and a 13 pt label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MoodChipRow(
            moods: <MoodList>[MoodList(mood: WallMood.dreamy, wallIds: <String>[])],
          ),
        ),
      ),
    );

    final Finder chip = find.byType(PrismChip);
    expect(tester.widget<PrismChip>(chip).compact, isTrue);
    expect(tester.getSize(chip).height, 44);
    final Finder pill = find.descendant(of: chip, matching: find.byType(AnimatedContainer));
    expect(tester.getSize(pill).height, 34);
    expect(tester.widget<Text>(find.text('Dreamy')).style?.fontSize, 13);
  });
}
