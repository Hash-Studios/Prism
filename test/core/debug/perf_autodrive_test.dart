import 'package:Prism/core/debug/perf_autodrive.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingRouter implements AppRouter {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('router touched: ${invocation.memberName}');
}

void main() {
  test('start does nothing when PRISM_PERF_AUTODRIVE is not set', () {
    expect(() => PerfAutodrive.start(_ThrowingRouter()), returnsNormally);
  });
}
