import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Color fillColor(WidgetTester tester) =>
      (tester
                  .widget<DecoratedBox>(
                    find.descendant(of: find.byType(PulseFill), matching: find.byType(DecoratedBox)),
                  )
                  .decoration
              as BoxDecoration)
          .color!;

  testWidgets('builds the subtree once while the fill colour animates', (tester) async {
    int builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PulsePlaceholder(
          builder: (context, _) {
            builds++;
            return const SizedBox(width: 40, height: 40, child: PulseFill());
          },
        ),
      ),
    );
    final Color c0 = fillColor(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(fillColor(tester), isNot(c0));
    expect(builds, 1);
  });

  testWidgets('stays still under reduce motion', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: PulsePlaceholder(builder: _fill)),
      ),
    );
    final Color c0 = fillColor(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(fillColor(tester), c0);
  });
}

Widget _fill(BuildContext context, Color color) => const SizedBox(width: 40, height: 40, child: PulseFill());
