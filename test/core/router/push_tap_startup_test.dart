import 'package:Prism/core/router/push_tap_startup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('routes immediately when startup is already done', (WidgetTester tester) async {
    final DateTime startedAt = tester.binding.clock.now();
    final Future<bool> wait = waitForPushTapStartup(isMounted: () => true, isReady: () => true);

    await tester.pump();

    expect(await wait, isTrue);
    expect(tester.binding.clock.now().difference(startedAt), Duration.zero);
  });

  testWidgets('waits until startup is ready', (WidgetTester tester) async {
    bool ready = false;
    final DateTime startedAt = tester.binding.clock.now();
    DateTime? completedAt;
    final Future<bool> wait = waitForPushTapStartup(isMounted: () => true, isReady: () => ready).then((result) {
      completedAt = tester.binding.clock.now();
      return result;
    });

    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.clock.now().difference(startedAt), const Duration(milliseconds: 100));
    expect(completedAt, isNull);

    await tester.pump(const Duration(milliseconds: 100));
    expect(completedAt, isNull);
    ready = true;
    await tester.pump(const Duration(milliseconds: 100));

    expect(await wait, isTrue);
    expect(completedAt!.difference(startedAt), const Duration(milliseconds: 300));
  });

  testWidgets('stops waiting when disposed even if startup later becomes ready', (WidgetTester tester) async {
    bool mounted = true;
    bool ready = false;
    final DateTime startedAt = tester.binding.clock.now();
    DateTime? completedAt;
    final Future<bool> wait = waitForPushTapStartup(isMounted: () => mounted, isReady: () => ready).then((result) {
      completedAt = tester.binding.clock.now();
      return result;
    });

    await tester.pump(const Duration(milliseconds: 100));
    mounted = false;
    ready = true;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 30));

    expect(await wait, isFalse);
    expect(completedAt!.difference(startedAt), const Duration(milliseconds: 200));
  });

  testWidgets('does not route when obsolete-version startup never becomes ready', (WidgetTester tester) async {
    final DateTime startedAt = tester.binding.clock.now();
    DateTime? completedAt;
    final Future<bool> wait = waitForPushTapStartup(isMounted: () => true, isReady: () => false).then((result) {
      completedAt = tester.binding.clock.now();
      return result;
    });

    await tester.pump(const Duration(seconds: 30));

    expect(await wait, isFalse);
    expect(completedAt!.difference(startedAt), const Duration(seconds: 30));
  });
}
