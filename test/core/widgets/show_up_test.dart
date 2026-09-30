import 'package:Prism/core/widgets/animated/show_up.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(bool reduce, {Duration delay = Duration.zero}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ShowUpTransition(forward: true, delay: delay, child: const Text('content')),
    ),
  );

  testWidgets('reduced motion shows content without the entrance delay', (tester) async {
    await tester.pumpWidget(host(true, delay: const Duration(milliseconds: 100)));
    expect(tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('settles its entrance when reduce motion changes', (tester) async {
    await tester.pumpWidget(host(false));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value, greaterThan(0));
    expect(tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value, lessThan(1));

    await tester.pumpWidget(host(true));
    expect(tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value, 1);
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
