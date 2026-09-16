import 'package:Prism/core/monitoring/error_reporter.dart';
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_error_reporter.dart';

void main() {
  test('defaults to Noop reporter and can be rebound/reset', () {
    MonitoringRuntime.reset();
    expect(MonitoringRuntime.reporter, isA<NoopErrorReporter>());

    MonitoringRuntime.reporter = FakeErrorReporter();
    expect(MonitoringRuntime.reporter.isEnabled, isTrue);

    MonitoringRuntime.reset();
    expect(MonitoringRuntime.reporter, isA<NoopErrorReporter>());
  });
}
