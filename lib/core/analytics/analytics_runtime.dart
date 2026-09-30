import 'package:Prism/core/analytics/analytics_route_observer.dart';
import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:flutter/widgets.dart';

class AnalyticsRuntime {
  AnalyticsRuntime._();

  static final ValueNotifier<AppAnalytics> changes = ValueNotifier<AppAnalytics>(const NoopAppAnalytics());

  static AppAnalytics get instance => changes.value;

  static set instance(AppAnalytics value) => changes.value = value;

  static List<NavigatorObserver> buildNavigatorObservers() => <NavigatorObserver>[
    AnalyticsRouteObserver(
      onScreenView: ({required String screenName, String? screenClass, Map<String, Object?>? parameters}) =>
          instance.logScreenView(screenName: screenName, screenClass: screenClass, parameters: parameters),
    ),
  ];

  static void reset() {
    instance = const NoopAppAnalytics();
  }
}
