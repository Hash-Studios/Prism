import 'package:Prism/core/monitoring/error_reporter.dart';

class MonitoringRuntime {
  MonitoringRuntime._();

  static ErrorReporter reporter = const NoopErrorReporter();

  static void reset() {
    reporter = const NoopErrorReporter();
  }
}
