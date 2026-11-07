import 'package:Prism/core/widgets/prism_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PrismMarkPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(find.descendant(of: find.byType(PrismLoader), matching: find.byType(CustomPaint)))
            .painter!
        as PrismMarkPainter;

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Center(child: child),
  ),
);

void main() {
  testWidgets('progress shows that step and does not animate', (tester) async {
    await tester.pumpWidget(_app(const PrismLoader.progress(0.5)));

    expect(_painter(tester).t, 0.5);
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.getSize(find.byType(PrismLoader)), const Size.square(28));
  });

  testWidgets('the loader loops through the steps in theme colours', (tester) async {
    await tester.pumpWidget(_app(const PrismLoader()));
    final double start = _painter(tester).t;
    await tester.pump(const Duration(milliseconds: 500));
    final PrismMarkPainter mid = _painter(tester);

    expect(tester.hasRunningAnimations, isTrue);
    expect(mid.t, greaterThan(start));
    final ColorScheme cs = Theme.of(tester.element(find.byType(PrismLoader))).colorScheme;
    expect(mid.ink, cs.onSurface);
    expect(mid.fill, cs.primary);

    // One loop later it starts over.
    await tester.pump(const Duration(milliseconds: 1400));
    expect(_painter(tester).t, closeTo(mid.t, 0.01));
  });

  testWidgets('with reduce motion the loader is the still, finished mark', (tester) async {
    await tester.pumpWidget(_app(const PrismLoader(), reduceMotion: true));

    expect(tester.hasRunningAnimations, isFalse);
    expect(_painter(tester).t, 1);
    expect(_painter(tester).opacity, 1);
  });
}
