import 'package:Prism/logger/log_sink.dart';
import 'package:flutter/foundation.dart';

enum AppLogLevel { debug, info, warn, error }

extension AppLogLevelLabel on AppLogLevel {
  String get shortLabel {
    switch (this) {
      case AppLogLevel.debug:
        return 'DBG';
      case AppLogLevel.info:
        return 'INF';
      case AppLogLevel.warn:
        return 'WRN';
      case AppLogLevel.error:
        return 'ERR';
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
  });

  final int sequence;
  final DateTime timestamp;
  final AppLogLevel level;
  final String message;
  final String? tag;
  final Object? error;
  final StackTrace? stackTrace;
  final LogFields fields;
}

class AppLogger {
  AppLogger({required LogSink sink, AppLogLevel? minimumLevel})
    : _sink = sink,
      _minimumLevel = minimumLevel ?? _defaultMinimumLevel();

  static int _sequenceCounter = 0;

  final LogSink _sink;
  final AppLogLevel _minimumLevel;

  void d(Object? message, {Object? error, StackTrace? stackTrace, String? tag, LogFields? fields}) {
    _write(AppLogLevel.debug, message, error: error, stackTrace: stackTrace, tag: tag, fields: fields);
  }

  void i(Object? message, {Object? error, StackTrace? stackTrace, String? tag, LogFields? fields}) {
    _write(AppLogLevel.info, message, error: error, stackTrace: stackTrace, tag: tag, fields: fields);
  }

  void w(Object? message, {Object? error, StackTrace? stackTrace, String? tag, LogFields? fields}) {
    _write(AppLogLevel.warn, message, error: error, stackTrace: stackTrace, tag: tag, fields: fields);
  }

  void e(Object? message, {Object? error, StackTrace? stackTrace, String? tag, LogFields? fields}) {
    _write(AppLogLevel.error, message, error: error, stackTrace: stackTrace, tag: tag, fields: fields);
  }

  void _write(
    AppLogLevel level,
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
    LogFields? fields,
  }) {
    if (!_shouldLog(level)) {
      return;
    }

    final AppLogRecord record = AppLogRecord(
      sequence: ++_sequenceCounter,
      timestamp: DateTime.now(),
      level: level,
      message: _asMessage(message),
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      fields: fields ?? const <String, Object?>{},
    );
    _sink.write(record);
  }

  bool _shouldLog(AppLogLevel level) {
    return level.index >= _minimumLevel.index;
  }

  String _asMessage(Object? message) {
    if (message == null) {
      return 'null';
    }
    return message.toString();
  }
}

AppLogLevel _defaultMinimumLevel() {
  return kReleaseMode ? AppLogLevel.warn : AppLogLevel.debug;
}
