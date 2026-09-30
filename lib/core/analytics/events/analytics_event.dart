abstract class AnalyticsEvent {
  const AnalyticsEvent();

  String get eventName;

  Map<String, Object?> toWireParameters();
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
