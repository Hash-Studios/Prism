import 'package:Prism/core/monitoring/error_reporter.dart';
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:Prism/core/monitoring/sentry_log_sink.dart';
import 'package:Prism/logger/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class _CaptureCall {
  _CaptureCall({
    required this.kind,
    required this.message,
    this.exception,
    this.stackTrace,
    required this.severity,
    required this.tag,
    required this.extras,
  });

  final String kind;
  final String message;
  final Object? exception;
  final StackTrace? stackTrace;
  final ErrorSeverity severity;
  final String? tag;
  final Map<String, Object?> extras;
}

class _FakeReporter extends ErrorReporter {
  _FakeReporter();
  final List<_CaptureCall> calls = <_CaptureCall>[];

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
    calls.add(
      _CaptureCall(
        kind: 'exception',
        message: message ?? '',
        exception: exception,
        stackTrace: stackTrace,
        severity: severity,
        tag: tag,
        extras: extras,
      ),
    );
    return null;
  }

  @override
  Future<SentryId?> captureMessage(
    String message, {
    ErrorSeverity severity = ErrorSeverity.error,
    String? tag,
    Map<String, Object?> extras = const <String, Object?>{},
  }) async {
    calls.add(
      _CaptureCall(
        kind: 'message',
        message: message,
        severity: severity,
        tag: tag,
        extras: extras,
      ),
    );
    return null;
  }

  @override
  Future<void> clearUser() async {}

  @override
  Future<void> setUser({required String id, required String email, String? username}) async {}
}

void main() {
  group('SentryLogSink', () {
    late _FakeReporter reporter;

    setUp(() {
      reporter = _FakeReporter();
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

      expect(reporter.calls, isEmpty);
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

      expect(reporter.calls, hasLength(1));
      expect(reporter.calls.first.kind, 'exception');
      expect(reporter.calls.first.exception, exception);
      expect(reporter.calls.first.stackTrace, stackTrace);
      expect(reporter.calls.first.message, 'Operation failed');
      expect(reporter.calls.first.tag, 'Auth');
      expect(reporter.calls.first.severity, ErrorSeverity.error);
    });

    test('captures logger.e message when exception is absent', () {
      final SentryLogSink sink = SentryLogSink();

      sink.write(record(level: AppLogLevel.error, message: 'Manual error marker', tag: 'Sync'));

      expect(reporter.calls, hasLength(1));
      expect(reporter.calls.first.kind, 'message');
      expect(reporter.calls.first.message, 'Manual error marker');
      expect(reporter.calls.first.tag, 'Sync');
      expect(reporter.calls.first.severity, ErrorSeverity.error);
    });

    test('dedupes burst duplicates inside configured window', () {
      final SentryLogSink sink = SentryLogSink(
        dedupeWindow: const Duration(seconds: 3),
        clock: () => DateTime(2026, 2, 17, 11),
      );

      sink.write(record(level: AppLogLevel.error, message: 'Duplicate candidate'));
      sink.write(record(level: AppLogLevel.error, message: 'Duplicate candidate'));

      expect(reporter.calls, hasLength(1));
    });
  });
}
