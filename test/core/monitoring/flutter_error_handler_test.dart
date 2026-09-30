import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/monitoring/flutter_error_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAppAnalytics extends NoopAppAnalytics {
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];

  @override
  Future<void> track(AnalyticsEvent event) async {
    events.add(event);
  }
}

void main() {
  late FlutterExceptionHandler? originalFlutterErrorHandler;
  late AppAnalytics originalAnalytics;

  setUp(() {
    originalFlutterErrorHandler = FlutterError.onError;
    originalAnalytics = AnalyticsRuntime.instance;
  });

  tearDown(() {
    FlutterError.onError = originalFlutterErrorHandler;
    AnalyticsRuntime.instance = originalAnalytics;
  });

  test('installed framework handler reports a nonfatal typed error event', () {
    final recorder = _RecordingAppAnalytics();
    AnalyticsRuntime.instance = recorder;
    installFlutterFrameworkErrorHandler();

    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError('framework failure'),
        stack: StackTrace.current,
        library: 'test library',
      ),
    );

    expect(recorder.events, hasLength(1));
    expect(recorder.events.single, isA<AppErrorEvent>());
    expect(recorder.events.single.eventName, 'app_error');
    expect(recorder.events.single.toWireParameters(), <String, Object?>{'error_source': 'flutter_framework'});
  });
}
