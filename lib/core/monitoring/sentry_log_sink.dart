import 'package:Prism/core/monitoring/error_reporter.dart';
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:Prism/logger/app_logger.dart';
import 'package:Prism/logger/log_sink.dart';

class SentryLogSink implements LogSink {
  SentryLogSink({this.dedupeWindow = const Duration(milliseconds: 1500), DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Duration dedupeWindow;
  final DateTime Function() _clock;
  final Map<String, DateTime> _recentEvents = <String, DateTime>{};

  @override
  void write(AppLogRecord record) {
    if (record.level != AppLogLevel.error && record.level != AppLogLevel.fatal) {
      return;
    }

    final ErrorReporter reporter = MonitoringRuntime.reporter;
    if (!reporter.isEnabled) {
      return;
    }

    _cleanupOldEntries();
    final String dedupeKey = _eventKey(record);
    final DateTime now = _clock();
    final DateTime? lastSeen = _recentEvents[dedupeKey];
    if (lastSeen != null && now.difference(lastSeen) < dedupeWindow) {
      return;
    }
    _recentEvents[dedupeKey] = now;

    final ErrorSeverity severity = record.level == AppLogLevel.fatal ? ErrorSeverity.fatal : ErrorSeverity.error;

    final Map<String, Object?> extras = <String, Object?>{
      'sequence': record.sequence,
      'timestamp': record.timestamp.toUtc().toIso8601String(),
      if (record.fields.isNotEmpty) 'fields': record.fields,
      if (record.spanId != null) 'span_id': record.spanId,
      if (record.tag != null) 'app_tag': record.tag,
      'log_level': record.level.name,
    };

    if (record.error != null) {
      reporter.captureException(
        record.error!,
        stackTrace: record.stackTrace,
        message: record.message,
        severity: severity,
        tag: record.tag,
        extras: extras,
      );
      return;
    }

    reporter.captureMessage(record.message, severity: severity, tag: record.tag, extras: extras);
  }

  void _cleanupOldEntries() {
    if (_recentEvents.isEmpty) {
      return;
    }
    final DateTime now = _clock();
    final List<String> keysToRemove = <String>[];
    for (final MapEntry<String, DateTime> entry in _recentEvents.entries) {
      if (now.difference(entry.value) >= dedupeWindow) {
        keysToRemove.add(entry.key);
      }
    }
    for (final String key in keysToRemove) {
      _recentEvents.remove(key);
    }
  }

  String _eventKey(AppLogRecord record) {
    final String errorType = record.error?.runtimeType.toString() ?? 'no_error';
    final String tag = record.tag ?? 'no_tag';
    return '${record.level.name}|$tag|${record.message}|$errorType';
  }
}
