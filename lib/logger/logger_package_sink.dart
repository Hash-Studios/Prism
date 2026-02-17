import 'package:Prism/logger/app_logger.dart';
import 'package:Prism/logger/log_sink.dart';

class LoggerPackageSink implements LogSink {
  @override
  void write(AppLogRecord record) {
    // Placeholder for phase 2 migration.
    // This adapter will route AppLogRecord events to package:logger.
    throw UnimplementedError('LoggerPackageSink is not enabled in phase 1.');
  }
}
