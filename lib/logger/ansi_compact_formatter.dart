import 'dart:io';

import 'package:Prism/logger/app_logger.dart';

class AnsiCompactFormatter {
  AnsiCompactFormatter({bool? enableColor}) : _enableColor = enableColor ?? _defaultColorEnabled();

  final bool _enableColor;

  List<String> format(AppLogRecord record) {
    final String timestamp = _formatTime(record.timestamp);
    final String level = _colorize(record.level.shortLabel, _colorCodeFor(record.level));

    final StringBuffer mainLine = StringBuffer()
      ..write(timestamp)
      ..write(' ')
      ..write(level)
      ..write(' #')
      ..write(record.sequence);

    if (record.tag != null && record.tag!.isNotEmpty) {
      mainLine
        ..write(' [')
        ..write(record.tag)
        ..write(']');
    }

    if (record.spanId != null && record.spanId!.isNotEmpty) {
      mainLine
        ..write(' {span=')
        ..write(record.spanId)
        ..write('}');
    }

    mainLine
      ..write(' ')
      ..write(record.message);

    if (record.fields.isNotEmpty) {
      mainLine.write(_formatFields(record.fields));
    }

    final List<String> lines = <String>[mainLine.toString()];

    if (record.error != null) {
      lines.add(_withContinuationPrefix('error=${record.error}'));
    }
    if (record.stackTrace != null) {
      lines.add(_withContinuationPrefix('stack=${record.stackTrace}'));
    }

    return lines;
  }

  String _withContinuationPrefix(String text) {
    final String prefix = _enableColor ? '\x1B[90m↳\x1B[0m' : '↳';
    return '$prefix $text';
  }

  String _formatFields(LogFields fields) {
    final StringBuffer buffer = StringBuffer();
    fields.forEach((String key, Object? value) {
      buffer
        ..write(' ')
        ..write(key)
        ..write('=')
        ..write(_formatFieldValue(value));
    });
    return buffer.toString();
  }

  String _formatFieldValue(Object? value) {
    if (value == null) {
      return 'null';
    }

    final String raw = value.toString();
    final bool needsQuotes = raw.contains(' ') || raw.contains('=');
    if (!needsQuotes) {
      return raw;
    }

    return '"${raw.replaceAll('"', r'\"')}"';
  }

  String _formatTime(DateTime dateTime) {
    final int hour = dateTime.hour;
    final int minute = dateTime.minute;
    final int second = dateTime.second;
    final int millisecond = dateTime.millisecond;
    return '${_twoDigits(hour)}:${_twoDigits(minute)}:${_twoDigits(second)}.${_threeDigits(millisecond)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _threeDigits(int value) => value.toString().padLeft(3, '0');

  String _colorize(String text, String colorCode) {
    if (!_enableColor) {
      return text;
    }
    return '\x1B[${colorCode}m$text\x1B[0m';
  }

  String _colorCodeFor(AppLogLevel level) {
    switch (level) {
      case AppLogLevel.trace:
        return '90';
      case AppLogLevel.debug:
        return '36';
      case AppLogLevel.info:
        return '32';
      case AppLogLevel.warn:
        return '33';
      case AppLogLevel.error:
        return '31';
      case AppLogLevel.fatal:
        return '35';
    }
  }

  static bool _defaultColorEnabled() {
    final bool noColorRequested = Platform.environment.containsKey('NO_COLOR');
    if (noColorRequested) {
      return false;
    }
    return stdout.supportsAnsiEscapes;
  }
}
