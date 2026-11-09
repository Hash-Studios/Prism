import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

void main() {
  test('a failed hint observer cannot stop feature analytics or later observers', () async {
    final FakeAppAnalytics target = FakeAppAnalytics();
    AnalyticsRuntime.instance = target;
    final List<AnalyticsEvent> observed = <AnalyticsEvent>[];
    final List<FlutterErrorDetails> errors = <FlutterErrorDetails>[];
    final FlutterExceptionHandler? previousHandler = FlutterError.onError;
    FlutterError.onError = errors.add;
    void broken(AnalyticsEvent _) => throw StateError('hint store unavailable');
    AnalyticsRuntime.trackListeners.addAll(<void Function(AnalyticsEvent)>[broken, observed.add]);
    addTearDown(() {
      AnalyticsRuntime.trackListeners.remove(broken);
      AnalyticsRuntime.trackListeners.remove(observed.add);
      FlutterError.onError = previousHandler;
      AnalyticsRuntime.reset();
    });

    const AnalyticsEvent event = PhotoSearchStartedEvent(signedIn: true, searchId: 'search');
    await AnalyticsRuntime.instance.track(event);
    await AnalyticsRuntime.instance.flush();

    expect(target.events, <AnalyticsEvent>[event]);
    expect(observed, <AnalyticsEvent>[event]);
    expect(errors.single.exception, isA<StateError>());
  });
}
