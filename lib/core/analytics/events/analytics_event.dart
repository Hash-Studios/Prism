import 'package:Prism/core/analytics/analytics_event_normalizer.dart';

abstract class AnalyticsEvent {
  const AnalyticsEvent();

  String get eventName;

  Map<String, Object?> toWireParameters();

  Map<String, Object> toNormalizedParameters(AnalyticsEventNormalizer normalizer) {
    return normalizer.normalizeParameters(toWireParameters());
  }
}

class ShareAnalyticsEvent extends AnalyticsEvent {
  const ShareAnalyticsEvent({required this.contentType, required this.itemId, required this.method});

  final String contentType;
  final String itemId;
  final String method;

  @override
  String get eventName => 'share';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'content_type': contentType, 'item_id': itemId, 'method': method};
  }
}

class LoginAnalyticsEvent extends AnalyticsEvent {
  const LoginAnalyticsEvent({this.loginMethod});

  final String? loginMethod;

  @override
  String get eventName => 'login';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'login_method': loginMethod};
  }
}

class ScreenViewAnalyticsEvent extends AnalyticsEvent {
  const ScreenViewAnalyticsEvent({required this.screenName, this.screenClass, this.parameters});

  final String screenName;
  final String? screenClass;
  final Map<String, Object?>? parameters;

  @override
  String get eventName => 'screen_view';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'screen_name': screenName, 'screen_class': screenClass, ...?parameters};
  }
}
