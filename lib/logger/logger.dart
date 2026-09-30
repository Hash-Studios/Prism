import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/core/monitoring/sentry_log_sink.dart';
import 'package:Prism/logger/app_logger.dart';
import 'package:Prism/logger/log_sink.dart';

final AppLogger logger = AppLogger(
  sink: CompositeLogSink(<LogSink>[PrintLogSink(), SentryLogSink(), InMemoryLogSink.instance]),
);
