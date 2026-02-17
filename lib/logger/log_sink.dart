import 'package:Prism/logger/ansi_compact_formatter.dart';
import 'package:Prism/logger/app_logger.dart';

abstract class LogSink {
  void write(AppLogRecord record);
}

class CompositeLogSink implements LogSink {
  CompositeLogSink(this._sinks);

  final List<LogSink> _sinks;

  @override
  void write(AppLogRecord record) {
    for (final LogSink sink in _sinks) {
      sink.write(record);
    }
  }
}

class PrintLogSink implements LogSink {
  PrintLogSink({AnsiCompactFormatter? formatter}) : _formatter = formatter ?? AnsiCompactFormatter();

  final AnsiCompactFormatter _formatter;

  @override
  void write(AppLogRecord record) {
    final List<String> lines = _formatter.format(record);
    for (final String line in lines) {
      // Intentionally using print for phase 1 to guarantee terminal visibility.
      // ignore: avoid_print
      print(line);
    }
  }
}
