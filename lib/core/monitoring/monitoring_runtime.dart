import 'package:Prism/core/monitoring/error_reporter.dart';
import 'package:Prism/core/monitoring/sentry_config.dart';

class MonitoringRuntime {
  MonitoringRuntime._();

  static ErrorReporter reporter = const NoopErrorReporter();

  /// The release and environment this run reports under. Set once at startup.
  static SentryConfig? config;

  static void reset() {
    reporter = const NoopErrorReporter();
  }
}
