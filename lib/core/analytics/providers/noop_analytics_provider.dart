import 'package:Prism/core/analytics/providers/analytics_provider.dart';

class NoopAnalyticsProvider implements AnalyticsProvider {
  const NoopAnalyticsProvider();

  @override
  Future<void> logEvent({required String name, Map<String, Object> parameters = const <String, Object>{}}) async {}

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
    Map<String, Object> parameters = const <String, Object>{},
  }) async {}

  @override
  Future<void> logShare({required String contentType, required String itemId, required String method}) async {}

  @override
  Future<void> flush() async {}
}
