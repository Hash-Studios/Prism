import 'package:Prism/core/analytics/providers/analytics_provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class FirebaseAnalyticsProvider implements AnalyticsProvider {
  FirebaseAnalyticsProvider({FirebaseAnalytics? analytics}) : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  /// iOS Info.plist denies ad storage, ad user data and ad personalization by default, so Analytics reads no
  /// advertising identifier. Call only after the user allows tracking.
  static Future<void> allowAdConsent() => FirebaseAnalytics.instance.setConsent(
    adStorageConsentGranted: true,
    adUserDataConsentGranted: true,
    adPersonalizationSignalsConsentGranted: true,
  );

  @override
  Future<void> logEvent({required String name, Map<String, Object> parameters = const <String, Object>{}}) {
    return _analytics.logEvent(name: name, parameters: parameters.isEmpty ? null : parameters);
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
  Future<void> flush() {
    return Future<void>.value();
  }
}
