import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:flutter/widgets.dart';

class AnalyticsFacade {
  const AnalyticsFacade();

  Future<void> track(AnalyticsEvent event) {
    return AnalyticsRuntime.instance.track(event);
  }

  Future<void> logShare({required String contentType, required String itemId, required String method}) {
    return AnalyticsRuntime.instance.logShare(contentType: contentType, itemId: itemId, method: method);
  }

  Future<void> logLogin({String? loginMethod}) {
    return AnalyticsRuntime.instance.logLogin(loginMethod: loginMethod);
  }

  Future<void> setUserId(String? userId) {
    return AnalyticsRuntime.instance.setUserId(userId);
  }

  Future<void> setUserProperty({required String name, String? value}) {
    return AnalyticsRuntime.instance.setUserProperty(name: name, value: value);
  }

  Future<void> logScreenView({required String screenName, String? screenClass, Map<String, Object?>? parameters}) {
    return AnalyticsRuntime.instance.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
      parameters: parameters,
    );
  }

  List<NavigatorObserver> buildNavigatorObservers() {
    return AnalyticsRuntime.instance.buildNavigatorObservers();
  }
}

const AnalyticsFacade analytics = AnalyticsFacade();
