import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/widgets.dart';

class _AnalyticsFacade {
  const _AnalyticsFacade();

  Future<void> track(AnalyticsEvent event) {
    logger.i('Tracking event: ${event.eventName}');
    return AnalyticsRuntime.instance.track(event);
  }

  Future<void> setUserId(String? userId) {
    return AnalyticsRuntime.instance.setUserId(userId);
  }

  Future<void> setUserProperty({required String name, String? value}) {
    return AnalyticsRuntime.instance.setUserProperty(name: name, value: value);
  }

  Future<void> flush() {
    return AnalyticsRuntime.instance.flush();
  }

  List<NavigatorObserver> buildNavigatorObservers() {
    return AnalyticsRuntime.instance.buildNavigatorObservers();
  }
}

const _AnalyticsFacade analytics = _AnalyticsFacade();
