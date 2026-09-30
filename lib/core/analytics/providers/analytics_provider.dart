abstract class AnalyticsProvider {
  Future<void> logEvent({required String name, Map<String, Object> parameters = const <String, Object>{}});

  Future<void> setUserId(String? userId);

  Future<void> setUserProperty({required String name, String? value});

  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object> parameters = const <String, Object>{},
  });

  Future<void> flush();
}
