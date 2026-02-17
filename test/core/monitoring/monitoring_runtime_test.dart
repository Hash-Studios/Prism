import 'package:Prism/core/monitoring/error_reporter.dart';
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class _EnabledReporter extends ErrorReporter {
  @override
  bool get isEnabled => true;

  @override
  Future<void> addBreadcrumb({
    required String message,
    String category = 'app.lifecycle',
    ErrorSeverity severity = ErrorSeverity.info,
    Map<String, Object?> data = const <String, Object?>{},
  }) async {}

  @override
  Future<SentryId?> captureException(
    Object exception, {
    StackTrace? stackTrace,
    String? message,
    ErrorSeverity severity = ErrorSeverity.error,
    String? tag,
    Map<String, Object?> extras = const <String, Object?>{},
  }) async {
    return null;
  }

  @override
  Future<SentryId?> captureMessage(
    String message, {
    ErrorSeverity severity = ErrorSeverity.error,
    String? tag,
    Map<String, Object?> extras = const <String, Object?>{},
  }) async {
    return null;
  }

  @override
  Future<void> clearUser() async {}

  @override
  Future<void> setUser({required String id, required String email, String? username}) async {}
}

void main() {
  test('defaults to Noop reporter and can be rebound/reset', () {
    MonitoringRuntime.reset();
    expect(MonitoringRuntime.reporter, isA<NoopErrorReporter>());

    MonitoringRuntime.reporter = _EnabledReporter();
    expect(MonitoringRuntime.reporter.isEnabled, isTrue);

    MonitoringRuntime.reset();
    expect(MonitoringRuntime.reporter, isA<NoopErrorReporter>());
  });
}
