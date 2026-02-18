import 'package:Prism/logger/log_sink.dart';
import 'package:flutter/foundation.dart';

enum AppLogLevel { trace, debug, info, warn, error, fatal }

extension AppLogLevelLabel on AppLogLevel {
  String get shortLabel {
    switch (this) {
      case AppLogLevel.trace:
        return 'TRC';
      case AppLogLevel.debug:
        return 'DBG';
      case AppLogLevel.info:
        return 'INF';
      case AppLogLevel.warn:
        return 'WRN';
      case AppLogLevel.error:
        return 'ERR';
      case AppLogLevel.fatal:
        return 'FTL';
    }
  }
}

typedef LogFields = Map<String, Object?>;

@immutable
class AppLogRecord {
  const AppLogRecord({
    required this.sequence,
    required this.timestamp,
    required this.level,
    required this.message,
    this.tag,
    this.error,
    this.stackTrace,
    this.fields = const <String, Object?>{},
    this.spanId,
  });

  final int sequence;
  final DateTime timestamp;
  final AppLogLevel level;
  final String message;
  final String? tag;
  final Object? error;
  final StackTrace? stackTrace;
  final LogFields fields;
  final String? spanId;
}

class AppLogger {
  AppLogger({required LogSink sink, AppLogLevel? minimumLevel})
      : _sink = sink,
        _minimumLevel = minimumLevel ?? _defaultMinimumLevel();

  static int _sequenceCounter = 0;

  final LogSink _sink;
  final AppLogLevel _minimumLevel;

  void t(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    String? tag,
    LogFields? fields,
    String? spanId,
  }) {
    _write(
      AppLogLevel.trace,
      message,
      time: time,
      error: error,
      stackTrace: stackTrace,
      tag: tag,
      fields: fields,
      spanId: spanId,
    );
  }

  void d(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    String? tag,
    LogFields? fields,
    String? spanId,
  }) {
    _write(
      AppLogLevel.debug,
      message,
      time: time,
      error: error,
      stackTrace: stackTrace,
      tag: tag,
      fields: fields,
      spanId: spanId,
    );
  }

  void i(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    String? tag,
    LogFields? fields,
    String? spanId,
  }) {
    _write(
      AppLogLevel.info,
      message,
      time: time,
      error: error,
      stackTrace: stackTrace,
      tag: tag,
      fields: fields,
      spanId: spanId,
    );
  }

  void w(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    String? tag,
    LogFields? fields,
    String? spanId,
  }) {
    _write(
      AppLogLevel.warn,
      message,
      time: time,
      error: error,
      stackTrace: stackTrace,
      tag: tag,
      fields: fields,
      spanId: spanId,
    );
  }

  void e(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    String? tag,
    LogFields? fields,
    String? spanId,
  }) {
    _write(
      AppLogLevel.error,
      message,
      time: time,
      error: error,
      stackTrace: stackTrace,
      tag: tag,
      fields: fields,
      spanId: spanId,
    );
  }

  void f(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    String? tag,
    LogFields? fields,
    String? spanId,
  }) {
    _write(
      AppLogLevel.fatal,
      message,
      time: time,
      error: error,
      stackTrace: stackTrace,
      tag: tag,
      fields: fields,
      spanId: spanId,
    );
  }

  void _write(
    AppLogLevel level,
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    String? tag,
    LogFields? fields,
    String? spanId,
  }) {
    if (!_shouldLog(level)) {
      return;
    }

    final AppLogRecord record = AppLogRecord(
      sequence: ++_sequenceCounter,
      timestamp: time ?? DateTime.now(),
      level: level,
      message: _asMessage(message),
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      fields: fields ?? const <String, Object?>{},
      spanId: spanId,
    );
    _sink.write(record);
  }

  bool _shouldLog(AppLogLevel level) {
    return level.index >= _minimumLevel.index;
  }

  String _asMessage(dynamic message) {
    if (message == null) {
      return 'null';
    }
    return message.toString();
  }
}

AppLogLevel _defaultMinimumLevel() {
  return kReleaseMode ? AppLogLevel.warn : AppLogLevel.trace;
}
