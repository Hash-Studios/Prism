import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:flutter/widgets.dart';

class FakeAppAnalytics implements AppAnalytics {
  final List<String?> userIds = <String?>[];
  final List<MapEntry<String, String?>> userProperties = <MapEntry<String, String?>>[];

  @override
  List<NavigatorObserver> buildNavigatorObservers() => const <NavigatorObserver>[];

  @override
  Future<void> flush() async {}

  @override
  Future<void> logLogin({String? loginMethod}) async {}

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object?>? parameters,
  }) async {}

  @override
  Future<void> logShare({required String contentType, required String itemId, required String method}) async {}

  @override
  Future<void> setUserId(String? userId) async {
    userIds.add(userId);
  }

  @override
  Future<void> setUserProperty({required String name, String? value}) async {
    userProperties.add(MapEntry<String, String?>(name, value));
  }

  @override
  Future<void> track(AnalyticsEvent event) async {}
}
