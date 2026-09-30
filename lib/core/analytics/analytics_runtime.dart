import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsRuntime {
  AnalyticsRuntime._();

  static final ValueNotifier<AppAnalytics> changes = ValueNotifier<AppAnalytics>(const NoopAppAnalytics());

  static AppAnalytics get instance => changes.value;

  static set instance(AppAnalytics value) => changes.value = value;

  static void reset() {
    instance = const NoopAppAnalytics();
  }
}
