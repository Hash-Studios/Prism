import 'package:Prism/logger/ansi_compact_formatter.dart';
import 'package:Prism/logger/app_logger.dart';
import 'package:Prism/logger/log_sink.dart';
import 'package:flutter_test/flutter_test.dart';

class _CollectingSink implements LogSink {
  final List<AppLogRecord> records = <AppLogRecord>[];

  @override
  void write(AppLogRecord record) {
    records.add(record);
  }
}

void main() {
  group('AppLogger', () {
    test('filters events below minimum level', () {
      final _CollectingSink sink = _CollectingSink();
      final AppLogger testLogger = AppLogger(sink: sink, minimumLevel: AppLogLevel.warn);

      testLogger.d('debug');
      testLogger.i('info');
      testLogger.w('warn');
      testLogger.e('error');

      expect(sink.records.length, 2);
      expect(sink.records[0].level, AppLogLevel.warn);
      expect(sink.records[1].level, AppLogLevel.error);
    });

    test('keeps method compatibility with named metadata arguments', () {
      final _CollectingSink sink = _CollectingSink();
      final AppLogger testLogger = AppLogger(sink: sink, minimumLevel: AppLogLevel.trace);
      final StackTrace stackTrace = StackTrace.current;

      testLogger.t('trace', tag: 'Boot');
      testLogger.d('debug', fields: const <String, Object?>{'phase': 1});
      testLogger.i('info', spanId: 'span-1');
      testLogger.w('warn', error: 'warning');
      testLogger.e('error', tag: 'Auth', error: StateError('boom'), stackTrace: stackTrace);
      testLogger.f('fatal');

      expect(sink.records.length, 6);
      expect(sink.records[0].tag, 'Boot');
      expect(sink.records[1].fields['phase'], 1);
      expect(sink.records[2].spanId, 'span-1');
      expect(sink.records[4].error, isA<StateError>());
      expect(sink.records[4].stackTrace, stackTrace);
    });
  });

  group('AnsiCompactFormatter', () {
    test('formats compact plain text without ANSI when color is disabled', () {
      final AnsiCompactFormatter formatter = AnsiCompactFormatter(enableColor: false);
      final AppLogRecord record = AppLogRecord(
        sequence: 1,
        timestamp: DateTime(2026, 2, 17, 10, 11, 12, 13),
        level: AppLogLevel.info,
        message: 'Signed in',
        tag: 'Onboarding',
        fields: const <String, Object?>{'provider': 'google', 'attempt': 2},
      );

      final List<String> lines = formatter.format(record);
      expect(lines, hasLength(1));
      expect(lines.first, contains('10:11:12.013'));
      expect(lines.first, contains('INF'));
      expect(lines.first, contains('[Onboarding]'));
      expect(lines.first, contains('provider=google'));
      expect(lines.first, contains('attempt=2'));
      expect(lines.first.contains('\x1B['), isFalse);
    });

    test('formats follow-up lines for error and stack trace', () {
      final AnsiCompactFormatter formatter = AnsiCompactFormatter(enableColor: true);
      final AppLogRecord record = AppLogRecord(
        sequence: 4,
        timestamp: DateTime(2026, 2, 17, 10, 11, 12, 13),
        level: AppLogLevel.error,
        message: 'Google sign-in failed',
        error: ArgumentError('Missing URL scheme'),
        stackTrace: StackTrace.current,
      );

      final List<String> lines = formatter.format(record);
      expect(lines.first.contains('\x1B['), isTrue);
      expect(lines.length, greaterThanOrEqualTo(3));
      expect(lines[1], contains('error='));
      expect(lines[2], contains('stack='));
    });
  });
}
