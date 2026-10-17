import 'package:flutter_test/flutter_test.dart';

/// Yields to real I/O and optionally advances the fake clock between readiness checks.
Future<void> waitForRealIo(
  WidgetTester tester,
  bool Function() isReady, {
  required String reason,
  Duration timeout = const Duration(seconds: 30),
  Duration pumpDuration = Duration.zero,
}) async {
  final stopwatch = Stopwatch()..start();
  await tester.pump();
  while (!isReady()) {
    if (stopwatch.elapsed >= timeout) {
      fail('Timed out after $timeout waiting for $reason.');
    }
    await tester.runAsync(() => Future<void>(() {}));
    await tester.pump(pumpDuration);
  }
}
