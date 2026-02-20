import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAppAnalytics implements AppAnalytics {
  @override
  List<NavigatorObserver> buildNavigatorObservers() => const <NavigatorObserver>[];

  @override
  Future<void> track(AnalyticsEvent event) async {}

  @override
  Future<void> logLogin({String? loginMethod}) async {}

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setUserProperty({required String name, String? value}) async {}

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object?>? parameters,
  }) async {}

  @override
  Future<void> logShare({required String contentType, required String itemId, required String method}) async {}
}

void main() {
  test('defaults to Noop and supports bind/reset', () {
    AnalyticsRuntime.reset();
    expect(AnalyticsRuntime.instance, isA<NoopAppAnalytics>());

    final _FakeAppAnalytics fake = _FakeAppAnalytics();
    AnalyticsRuntime.instance = fake;
    expect(identical(AnalyticsRuntime.instance, fake), isTrue);

    AnalyticsRuntime.reset();
    expect(AnalyticsRuntime.instance, isA<NoopAppAnalytics>());
  });
}
