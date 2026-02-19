import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:flutter/widgets.dart';

class AnalyticsFacade {
  const AnalyticsFacade();

  Future<void> logEvent({required String name, Map<String, Object?>? parameters}) {
    return AnalyticsRuntime.instance.logEvent(name: name, parameters: parameters);
  }

  Future<void> logShare({required String contentType, required String itemId, required String method}) {
    return AnalyticsRuntime.instance.logShare(contentType: contentType, itemId: itemId, method: method);
  }

  Future<void> logLogin({String? loginMethod}) {
    return AnalyticsRuntime.instance.logLogin(loginMethod: loginMethod);
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
