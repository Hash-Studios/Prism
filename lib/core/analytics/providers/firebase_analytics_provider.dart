import 'package:Prism/core/analytics/providers/analytics_provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class FirebaseAnalyticsProvider implements AnalyticsProvider {
  FirebaseAnalyticsProvider({FirebaseAnalytics? analytics}) : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent({required String name, Map<String, Object> parameters = const <String, Object>{}}) {
    return _analytics.logEvent(name: name, parameters: parameters.isEmpty ? null : parameters);
  }

  @override
  Future<void> logLogin({String? loginMethod}) {
    return _analytics.logLogin(loginMethod: loginMethod);
  }

  @override
  Future<void> setUserId(String? userId) {
    return _analytics.setUserId(id: userId);
  }

  @override
  Future<void> setUserProperty({required String name, String? value}) {
    return _analytics.setUserProperty(name: name, value: value);
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object> parameters = const <String, Object>{},
  }) {
    return _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
      parameters: parameters.isEmpty ? null : parameters,
    );
  }

  @override
  Future<void> logShare({required String contentType, required String itemId, required String method}) {
    return _analytics.logShare(contentType: contentType, itemId: itemId, method: method);
  }
}
