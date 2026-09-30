import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';

void installFlutterFrameworkErrorHandler() {
  FlutterError.onError = _handleFlutterFrameworkError;
}

void _handleFlutterFrameworkError(FlutterErrorDetails details) {
  FlutterError.dumpErrorToConsole(details, forceReport: true);
  logger.e(
    'Uncaught Flutter framework error',
    tag: 'FlutterError',
    error: details.exception,
    stackTrace: details.stack,
    fields: <String, Object?>{
      if (details.library != null) 'library': details.library,
      if (details.context != null) 'context': details.context.toString(),
    },
  );
  unawaited(analytics.track(const AppErrorEvent(errorSource: 'flutter_framework')));
}
