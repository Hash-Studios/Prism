import 'package:Prism/core/analytics/analytics_event_normalizer.dart';
import 'package:Prism/core/analytics/analytics_route_observer.dart';
import 'package:Prism/core/analytics/providers/analytics_provider.dart';
import 'package:flutter/widgets.dart';

abstract class AppAnalytics {
  Future<void> logEvent({required String name, Map<String, Object?>? parameters});

  Future<void> logShare({required String contentType, required String itemId, required String method});

  Future<void> logLogin({String? loginMethod});

  Future<void> setUserId(String? userId);

  Future<void> setUserProperty({required String name, String? value});

  Future<void> logScreenView({required String screenName, String? screenClass, Map<String, Object?>? parameters});

  List<NavigatorObserver> buildNavigatorObservers();
}

class ProviderBackedAppAnalytics implements AppAnalytics {
  ProviderBackedAppAnalytics({
    required AnalyticsProvider provider,
    AnalyticsEventNormalizer normalizer = const AnalyticsEventNormalizer(),
  }) : _provider = provider,
       _normalizer = normalizer;

  final AnalyticsProvider _provider;
  final AnalyticsEventNormalizer _normalizer;

  late final AnalyticsRouteObserver _routeObserver = AnalyticsRouteObserver(onScreenView: logScreenView);

  @override
  Future<void> logEvent({required String name, Map<String, Object?>? parameters}) {
    final NormalizedAnalyticsEvent normalized = _normalizer.normalizeEvent(name: name, parameters: parameters);
    return _provider.logEvent(name: normalized.name, parameters: normalized.parameters);
  }

  @override
  Future<void> logShare({required String contentType, required String itemId, required String method}) {
    return _provider.logShare(
      contentType: _nonEmpty(contentType, fallback: 'unknown_content'),
      itemId: _nonEmpty(itemId, fallback: 'unknown_item'),
      method: _nonEmpty(method, fallback: 'unknown_method'),
    );
  }

  @override
  Future<void> logLogin({String? loginMethod}) {
    return _provider.logLogin(loginMethod: _nonEmptyOrNull(loginMethod));
  }

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
    return _provider.logScreenView(
      screenName: _normalizer.normalizeScreenName(screenName),
      screenClass: _nonEmptyOrNull(screenClass),
      parameters: _normalizer.normalizeParameters(parameters),
    );
  }

  @override
  List<NavigatorObserver> buildNavigatorObservers() {
    return <NavigatorObserver>[_routeObserver];
  }

  String _nonEmpty(String value, {required String fallback}) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }
    return trimmed;
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
  List<NavigatorObserver> buildNavigatorObservers() => const <NavigatorObserver>[];

  @override
  Future<void> logEvent({required String name, Map<String, Object?>? parameters}) async {}

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
