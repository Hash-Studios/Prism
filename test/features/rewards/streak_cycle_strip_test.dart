import 'package:Prism/features/rewards/views/widgets/streak_cycle_strip.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(20), child: child),
  ),
);

void main() {
  for (final ThemeData theme in <ThemeData>[kLightTheme, kDarkTheme]) {
    testWidgets('strip fills done days with onPrimary ticks and marks today (${theme.brightness.name})', (
      tester,
    ) async {
      await tester.pumpWidget(_app(theme, const StreakCycleStrip(cycleDay: 2, todayDay: 3)));
      await tester.pump(const Duration(seconds: 1));
      final ColorScheme cs = theme.colorScheme;
      final Iterable<Icon> ticks = tester.widgetList<Icon>(find.byIcon(Icons.check_rounded));
      expect(ticks.length, 2);
      for (final Icon tick in ticks) {
        expect(tick.color, cs.onPrimary);
      }
      final Container firstDay = tester.widget<Container>(
        find.ancestor(of: find.byIcon(Icons.check_rounded).first, matching: find.byType(Container)).first,
      );
      expect((firstDay.decoration! as BoxDecoration).color, cs.primary);
      expect(find.text('Day 3'), findsOneWidget);
      expect(find.text('+8'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('strip can hide rewards and plays again when the day changes', (tester) async {
    await tester.pumpWidget(_app(kDarkTheme, const StreakCycleStrip(cycleDay: 1, showRewards: false)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('+5'), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pumpWidget(_app(kDarkTheme, const StreakCycleStrip(cycleDay: 2, showRewards: false)));
    await tester.pump(const Duration(milliseconds: 20));
    final Opacity fading = tester.widget<Opacity>(
      find.ancestor(of: find.byIcon(Icons.check_rounded).first, matching: find.byType(Opacity)).first,
    );
    expect(fading.opacity, lessThan(1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
  });
}
