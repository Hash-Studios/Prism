import 'package:flutter_test/flutter_test.dart';

/// Yields to real I/O without advancing the widget test's fake clock.
Future<void> waitForRealIo(
  WidgetTester tester,
  bool Function() isReady, {
  required String reason,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final stopwatch = Stopwatch()..start();
  await tester.pump();
  while (!isReady()) {
    if (stopwatch.elapsed >= timeout) {
      fail('Timed out after $timeout waiting for $reason.');
    }
    await tester.runAsync(() => Future<void>(() {}));
    await tester.pump();
  }
}
