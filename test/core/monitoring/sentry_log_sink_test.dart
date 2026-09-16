import 'package:Prism/core/monitoring/error_reporter.dart';
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:Prism/core/monitoring/sentry_log_sink.dart';
import 'package:Prism/logger/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_error_reporter.dart';

void main() {
  group('SentryLogSink', () {
    late FakeErrorReporter reporter;

    setUp(() {
      reporter = FakeErrorReporter();
      MonitoringRuntime.reporter = reporter;
    });

    tearDown(() {
      MonitoringRuntime.reset();
    });

    AppLogRecord record({
      required AppLogLevel level,
      required String message,
      Object? error,
      StackTrace? stackTrace,
      String? tag,
    }) {
      return AppLogRecord(
        sequence: 1,
        timestamp: DateTime(2026, 2, 17, 10),
        level: level,
        message: message,
        tag: tag,
        error: error,
        stackTrace: stackTrace,
      );
    }

    test('ignores non-error log levels', () {
      final SentryLogSink sink = SentryLogSink();

      sink.write(record(level: AppLogLevel.info, message: 'informational'));

      expect(reporter.capturedExceptions, isEmpty);
      expect(reporter.capturedMessages, isEmpty);
    });

    test('captures logger.e with exception and stacktrace', () {
      final SentryLogSink sink = SentryLogSink();
      final Exception exception = Exception('boom');
      final StackTrace stackTrace = StackTrace.current;

      sink.write(
        record(
          level: AppLogLevel.error,
          message: 'Operation failed',
          error: exception,
          stackTrace: stackTrace,
          tag: 'Auth',
        ),
      );

      expect(reporter.capturedExceptions, hasLength(1));
      expect(reporter.capturedMessages, isEmpty);
      expect(reporter.capturedExceptions.first.exception, exception);
      expect(reporter.capturedExceptions.first.stackTrace, stackTrace);
      expect(reporter.capturedExceptions.first.message, 'Operation failed');
      expect(reporter.capturedExceptions.first.tag, 'Auth');
      expect(reporter.capturedExceptions.first.severity, ErrorSeverity.error);
    });

    test('captures logger.e message when exception is absent', () {
      final SentryLogSink sink = SentryLogSink();

      sink.write(record(level: AppLogLevel.error, message: 'Manual error marker', tag: 'Sync'));

      expect(reporter.capturedMessages, hasLength(1));
      expect(reporter.capturedExceptions, isEmpty);
      expect(reporter.capturedMessages.first.message, 'Manual error marker');
      expect(reporter.capturedMessages.first.tag, 'Sync');
      expect(reporter.capturedMessages.first.severity, ErrorSeverity.error);
    });

    test('dedupes burst duplicates inside configured window', () {
      final SentryLogSink sink = SentryLogSink(
        dedupeWindow: const Duration(seconds: 3),
        clock: () => DateTime(2026, 2, 17, 11),
      );

      sink.write(record(level: AppLogLevel.error, message: 'Duplicate candidate'));
      sink.write(record(level: AppLogLevel.error, message: 'Duplicate candidate'));

      expect(reporter.capturedMessages, hasLength(1));
      expect(reporter.capturedExceptions, isEmpty);
    });
  });
}
