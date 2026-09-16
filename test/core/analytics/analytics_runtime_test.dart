import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

void main() {
  test('defaults to Noop and supports bind/reset', () {
    AnalyticsRuntime.reset();
    expect(AnalyticsRuntime.instance, isA<NoopAppAnalytics>());

    final FakeAppAnalytics fake = FakeAppAnalytics();
    AnalyticsRuntime.instance = fake;
    expect(identical(AnalyticsRuntime.instance, fake), isTrue);

    AnalyticsRuntime.reset();
    expect(AnalyticsRuntime.instance, isA<NoopAppAnalytics>());
  });
}
