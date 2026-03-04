import 'package:Prism/core/monitoring/sentry_log_sink.dart';
import 'package:Prism/logger/app_logger.dart';
import 'package:Prism/logger/log_sink.dart';
import 'package:flutter/foundation.dart';

final AppLogger logger = AppLogger(
  minimumLevel: kReleaseMode ? AppLogLevel.warn : AppLogLevel.trace,
  sink: CompositeLogSink(<LogSink>[PrintLogSink(), SentryLogSink()]),
);

const String logExportDisabledMarker = 'DISABLED::::';

Future<String> zipLogs() async {
  logger.w('Log export is temporarily disabled during the phase-1 logger migration.', tag: 'Logger');
  return logExportDisabledMarker;
}
