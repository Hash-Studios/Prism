import 'package:Prism/core/motion/prism_motion.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Duration> read(WidgetTester tester, {required bool reduce}) async {
    late Duration result;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Builder(
          builder: (context) {
            result = context.motion(PrismDurations.base);
            return const SizedBox();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('motion returns the duration when animations are on', (tester) async {
    expect(await read(tester, reduce: false), PrismDurations.base);
  });

  testWidgets('motion returns zero when animations are disabled', (tester) async {
    expect(await read(tester, reduce: true), Duration.zero);
  });
}
