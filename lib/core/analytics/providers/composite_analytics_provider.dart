import 'package:Prism/core/analytics/providers/analytics_provider.dart';
import 'package:Prism/logger/logger.dart';

class CompositeAnalyticsProvider implements AnalyticsProvider {
  CompositeAnalyticsProvider(List<AnalyticsProvider> providers, {bool logProviderFailures = true})
    : _providers = List<AnalyticsProvider>.unmodifiable(providers),
      _logProviderFailures = logProviderFailures;

  final List<AnalyticsProvider> _providers;
  final bool _logProviderFailures;

  @override
  Future<void> logEvent({required String name, Map<String, Object> parameters = const <String, Object>{}}) {
    return _fanOut(
      (AnalyticsProvider provider) => provider.logEvent(name: name, parameters: parameters),
      operation: 'logEvent',
    );
  }

  @override
  Future<void> logLogin({String? loginMethod}) {
    return _fanOut((AnalyticsProvider provider) => provider.logLogin(loginMethod: loginMethod), operation: 'logLogin');
  }

  @override
  Future<void> setUserId(String? userId) {
    return _fanOut((AnalyticsProvider provider) => provider.setUserId(userId), operation: 'setUserId');
  }

  @override
  Future<void> setUserProperty({required String name, String? value}) {
    return _fanOut(
      (AnalyticsProvider provider) => provider.setUserProperty(name: name, value: value),
      operation: 'setUserProperty',
    );
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object> parameters = const <String, Object>{},
  }) {
    return _fanOut(
      (AnalyticsProvider provider) =>
          provider.logScreenView(screenName: screenName, screenClass: screenClass, parameters: parameters),
      operation: 'logScreenView',
    );
  }

  @override
  Future<void> logShare({required String contentType, required String itemId, required String method}) {
    return _fanOut(
      (AnalyticsProvider provider) => provider.logShare(contentType: contentType, itemId: itemId, method: method),
      operation: 'logShare',
    );
  }

  @override
  Future<void> flush() {
    return _fanOut((AnalyticsProvider provider) => provider.flush(), operation: 'flush');
  }

  Future<void> _fanOut(Future<void> Function(AnalyticsProvider provider) dispatch, {required String operation}) async {
    for (final AnalyticsProvider provider in _providers) {
      try {
        await dispatch(provider);
      } catch (error, stackTrace) {
        if (!_logProviderFailures) {
          continue;
        }
        logger.w(
          'Analytics provider failed during dispatch.',
          tag: 'Analytics',
          error: error,
          stackTrace: stackTrace,
          fields: <String, Object?>{'operation': operation, 'provider': provider.runtimeType.toString()},
        );
      }
    }
  }
}
