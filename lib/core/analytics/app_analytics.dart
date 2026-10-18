import 'package:Prism/core/analytics/analytics_event_normalizer.dart';
import 'package:Prism/core/analytics/analytics_correlation.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/analytics/providers/analytics_provider.dart';

abstract class AppAnalytics {
  Future<void> track(AnalyticsEvent event);

  Future<void> setUserId(String? userId);

  Future<void> setUserProperty({required String name, String? value});

  Future<void> logScreenView({required String screenName, String? screenClass, Map<String, Object?>? parameters});

  Future<void> flush();
}

class ProviderBackedAppAnalytics implements AppAnalytics {
  ProviderBackedAppAnalytics({
    required AnalyticsProvider provider,
    AnalyticsEventNormalizer normalizer = const AnalyticsEventNormalizer(),
  }) : _provider = provider,
       _normalizer = normalizer;

  final AnalyticsProvider _provider;
  final AnalyticsEventNormalizer _normalizer;
  final String _sessionId = AnalyticsCorrelation.newId();

  @override
  Future<void> track(AnalyticsEvent event) {
    if (event is ScreenViewAnalyticsEvent) {
      return _provider.logScreenView(
        screenName: _normalizer.normalizeScreenName(event.screenName),
        screenClass: _nonEmptyOrNull(event.screenClass),
        parameters: _normalizer.normalizeParameters(_withContext(event.parameters)),
      );
    }

    final NormalizedAnalyticsEvent normalized = _normalizer.normalizeEvent(
      name: event.eventName,
      parameters: _withContext(event.toWireParameters()),
    );
    return _provider.logEvent(name: normalized.name, parameters: normalized.parameters);
  }

  Map<String, Object?> _withContext(Map<String, Object?>? parameters) => <String, Object?>{
    ...?parameters,
    'analytics_session_id': _sessionId,
    'analytics_schema_version': 2,
  };

  @override
  Future<void> setUserId(String? userId) {
    return _provider.setUserId(_nonEmptyOrNull(userId));
  }

  @override
  Future<void> setUserProperty({required String name, String? value}) {
    final String propertyName = _normalizer.normalizePropertyName(name);
    if (propertyName == 'unknown_property') {
      return Future<void>.value();
    }
    return _provider.setUserProperty(name: propertyName, value: _nonEmptyOrNull(value));
  }

  @override
  Future<void> logScreenView({required String screenName, String? screenClass, Map<String, Object?>? parameters}) {
    return track(ScreenViewAnalyticsEvent(screenName: screenName, screenClass: screenClass, parameters: parameters));
  }

  @override
  Future<void> flush() {
    return _provider.flush();
  }

  String? _nonEmptyOrNull(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

class NoopAppAnalytics implements AppAnalytics {
  const NoopAppAnalytics();

  @override
  Future<void> track(AnalyticsEvent event) async {}

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
  Future<void> flush() async {}
}
