import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settles a held press when reduce motion changes', (tester) async {
    Widget host(bool reduce) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: PressScale(child: SizedBox(width: 100, height: 100))),
      ),
    );
    await tester.pumpWidget(host(false));
    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(PressScale)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final Finder transform = find.descendant(of: find.byType(PressScale), matching: find.byType(Transform));
    expect(tester.widget<Transform>(transform).transform.storage[0], lessThan(1));

    await tester.pumpWidget(host(true));
    expect(tester.widget<Transform>(transform).transform.storage[0], 1);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<Transform>(transform).transform.storage[0], 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('scales down on press, returns after release, and keeps child taps', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PressScale(
            child: GestureDetector(
              onTap: () => taps++,
              child: const SizedBox(width: 100, height: 100, child: ColoredBox(color: Colors.red)),
            ),
          ),
        ),
      ),
    );
    double scale() => tester
        .widget<Transform>(find.descendant(of: find.byType(PressScale), matching: find.byType(Transform)))
        .transform
        .storage[0];

    expect(scale(), 1);
    final TestGesture g = await tester.startGesture(tester.getCenter(find.byType(PressScale)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(), lessThan(1));
    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(), 1);
    expect(taps, 1);
  });
}
