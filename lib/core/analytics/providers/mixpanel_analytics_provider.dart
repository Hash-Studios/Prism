import 'package:Prism/core/analytics/providers/analytics_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

abstract class MixpanelClient {
  void track(String eventName, {Map<String, Object>? properties});

  void identify(String userId);

  void reset();

  void setUserProperty({required String name, required Object value});

  Future<void> flush();
}

class MixpanelFlutterClient implements MixpanelClient {
  MixpanelFlutterClient(this._mixpanel);

  final Mixpanel _mixpanel;

  @override
  void track(String eventName, {Map<String, Object>? properties}) {
    _mixpanel.track(eventName, properties: properties);
  }

  @override
  void identify(String userId) {
    _mixpanel.identify(userId);
  }

  @override
  void reset() {
    _mixpanel.reset();
  }

  @override
  void setUserProperty({required String name, required Object value}) {
    _mixpanel.registerSuperProperties(<String, Object>{name: value});
    _mixpanel.getPeople().set(name, value);
  }

  @override
  Future<void> flush() {
    return _mixpanel.flush();
  }
}

class MixpanelAnalyticsProvider implements AnalyticsProvider {
  MixpanelAnalyticsProvider._(this._client);

  final MixpanelClient _client;

  static Future<MixpanelAnalyticsProvider> create({required String token, bool trackAutomaticEvents = false}) async {
    final Mixpanel mixpanel = await Mixpanel.init(token, trackAutomaticEvents: trackAutomaticEvents);
    return MixpanelAnalyticsProvider._(MixpanelFlutterClient(mixpanel));
  }

  @visibleForTesting
  factory MixpanelAnalyticsProvider.forClient(MixpanelClient client) {
    return MixpanelAnalyticsProvider._(client);
  }

  @override
  Future<void> logEvent({required String name, Map<String, Object> parameters = const <String, Object>{}}) async {
    _client.track(name, properties: parameters.isEmpty ? null : parameters);
  }

  @override
  Future<void> logShare({required String contentType, required String itemId, required String method}) async {
    _client.track(
      'share',
      properties: <String, Object>{'content_type': contentType, 'item_id': itemId, 'method': method},
    );
  }

  @override
  Future<void> logLogin({String? loginMethod}) async {
    final Map<String, Object> properties = <String, Object>{};
    if (loginMethod != null && loginMethod.trim().isNotEmpty) {
      properties['login_method'] = loginMethod;
    }
    _client.track('login', properties: properties.isEmpty ? null : properties);
  }

  @override
  Future<void> setUserId(String? userId) async {
    final String trimmed = userId?.trim() ?? '';
    if (trimmed.isEmpty) {
      _client.reset();
      return;
    }
    _client.identify(trimmed);
  }

  @override
  Future<void> setUserProperty({required String name, String? value}) async {
    final String propertyName = name.trim();
    if (propertyName.isEmpty) {
      return;
    }
    final String? propertyValue = value?.trim();
    if (propertyValue == null || propertyValue.isEmpty) {
      return;
    }
    _client.setUserProperty(name: propertyName, value: propertyValue);
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object> parameters = const <String, Object>{},
  }) async {
    final Map<String, Object> properties = <String, Object>{
      'screen_name': screenName,
      if (screenClass != null && screenClass.trim().isNotEmpty) 'screen_class': screenClass,
      ...parameters,
    };
    _client.track('screen_view', properties: properties);
  }

  @override
  Future<void> flush() {
    return _client.flush();
  }
}
