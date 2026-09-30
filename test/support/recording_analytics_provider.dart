import 'package:Prism/core/analytics/providers/analytics_provider.dart';

class RecordingAnalyticsProvider implements AnalyticsProvider {
  final List<String> calls = <String>[];
  final List<({String name, Map<String, Object> parameters})> events =
      <({String name, Map<String, Object> parameters})>[];
  final List<({String name, String? screenClass, Map<String, Object> parameters})> screenViews =
      <({String name, String? screenClass, Map<String, Object> parameters})>[];
  final List<String?> userIds = <String?>[];
  final Map<String, String?> userProperties = <String, String?>{};

  @override
  Future<void> logEvent({required String name, Map<String, Object> parameters = const <String, Object>{}}) async {
    calls.add('log_event');
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> setUserId(String? userId) async {
    calls.add('set_user_id');
    userIds.add(userId);
  }

  @override
  Future<void> setUserProperty({required String name, String? value}) async {
    calls.add('set_user_property');
    userProperties[name] = value;
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object> parameters = const <String, Object>{},
  }) async {
    calls.add('log_screen_view');
    screenViews.add((name: screenName, screenClass: screenClass, parameters: parameters));
  }

  @override
  Future<void> flush() async {
    calls.add('flush');
  }
}
