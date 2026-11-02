import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/widgets/prism/prism_chip.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/views/widgets/mood_chip_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Proxima Nova')..addFont(rootBundle.load('assets/fonts/Proxima Nova Bold.otf'))).load();
  });

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
              MoodList(mood: WallMood.dreamy, wallIds: <String>['wall']),
              MoodList(mood: WallMood.darkQuiet, wallIds: <String>['wall']),
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

  testWidgets('hides an empty Duo chip and shows a populated Duo chip', (tester) async {
    Future<void> pump(List<String> ids) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MoodChipRow(
            moods: <MoodList>[MoodList(mood: WallMood.duoReveal, wallIds: ids)],
          ),
        ),
      ),
    );
    await pump(<String>[]);
    expect(find.byType(PrismChip), findsNothing);
    await pump(<String>['duo']);
    expect(find.text('Duo reveal'), findsOneWidget);
  });

  testWidgets('the row is labelled Moods for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MoodChipRow(
            moods: <MoodList>[
              MoodList(mood: WallMood.dreamy, wallIds: <String>['wall']),
            ],
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
            moods: <MoodList>[
              MoodList(mood: WallMood.dreamy, wallIds: <String>['wall']),
            ],
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

  for (final ThemeMode mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    for (final double scale in <double>[1.5, 2, 3]) {
      testWidgets('compact mood labels fit the 44 pt row at ${scale}x in ${mode.name} mode', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: kLightTheme,
            darkTheme: kDarkTheme,
            themeMode: mode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(
              body: MoodChipRow(
                moods: <MoodList>[
                  MoodList(mood: WallMood.dreamy, wallIds: <String>['wall']),
                  MoodList(mood: WallMood.darkQuiet, wallIds: <String>['wall']),
                ],
              ),
            ),
          ),
        );

        expect(tester.getSize(find.byType(ListView)).height, 44);
        for (final String label in <String>['Dreamy', 'Dark and quiet']) {
          final Finder text = find.text(label);
          final RenderParagraph paragraph = tester.renderObject(text);
          final Finder chip = find.ancestor(of: text, matching: find.byType(PrismChip));
          final Finder pill = find.descendant(of: chip, matching: find.byType(AnimatedContainer));
          expect(tester.getSize(chip).height, 44);
          expect(tester.getSize(pill).height, 34);
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(paragraph.textScaler.scale(13), scale.clamp(0, 2) * 13);
          expect(paragraph.size.height, greaterThanOrEqualTo(paragraph.getMaxIntrinsicHeight(paragraph.size.width)));
          expect(tester.getRect(text).top, greaterThanOrEqualTo(tester.getRect(pill).top));
          expect(tester.getRect(text).bottom, lessThanOrEqualTo(tester.getRect(pill).bottom));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
