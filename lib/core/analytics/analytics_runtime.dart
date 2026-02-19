import 'package:Prism/core/analytics/app_analytics.dart';

class AnalyticsRuntime {
  AnalyticsRuntime._();

  static AppAnalytics instance = const NoopAppAnalytics();

  static void reset() {
    instance = const NoopAppAnalytics();
  }
}
