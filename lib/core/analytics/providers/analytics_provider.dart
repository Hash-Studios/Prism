abstract class AnalyticsProvider {
  Future<void> logEvent({required String name, Map<String, Object> parameters = const <String, Object>{}});

  Future<void> logShare({required String contentType, required String itemId, required String method});

  Future<void> logLogin({String? loginMethod});

  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object> parameters = const <String, Object>{},
  });
}
