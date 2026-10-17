import 'package:flutter_test/flutter_test.dart';

import 'wait_for_real_io.dart';

void main() {
  testWidgets('yields to real events until ready without advancing fake time', (tester) async {
    final before = tester.binding.clock.now();
    var ready = false;
    await tester.runAsync(() async {
      Future<void>(() => ready = true);
    });

    await waitForRealIo(tester, () => ready, reason: 'real event completion');

    expect(ready, isTrue);
    expect(tester.binding.clock.now(), before);
  });

  testWidgets('a stalled condition fails with the step reason', (tester) async {
    await expectLater(
      () => waitForRealIo(tester, () => false, reason: 'native save completion', timeout: Duration.zero),
      throwsA(isA<TestFailure>().having((error) => error.message, 'message', contains('native save completion'))),
    );
  });

  testWidgets('an optional frame duration advances animations until ready', (tester) async {
    final before = tester.binding.clock.now();
    var ready = false;
    Future<void>.delayed(const Duration(milliseconds: 32), () => ready = true);

    await waitForRealIo(
      tester,
      () => ready,
      reason: 'fake-clock animation completion',
      pumpDuration: const Duration(milliseconds: 16),
    );

    expect(ready, isTrue);
    expect(tester.binding.clock.now().difference(before), const Duration(milliseconds: 32));
  });
}
