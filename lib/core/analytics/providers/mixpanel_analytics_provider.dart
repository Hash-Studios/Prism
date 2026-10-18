import 'package:Prism/core/analytics/providers/analytics_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

abstract class MixpanelClient {
  Future<void> track(String eventName, {Map<String, Object>? properties});

  Future<void> identify(String userId);

  Future<void> reset();

  Future<void> setUserProperty({required String name, required Object value});

  Future<void> flush();
}

class MixpanelFlutterClient implements MixpanelClient {
  MixpanelFlutterClient(this._mixpanel);

  final Mixpanel _mixpanel;

  @override
  Future<void> track(String eventName, {Map<String, Object>? properties}) {
    return _mixpanel.track(eventName, properties: properties);
  }

  @override
  Future<void> identify(String userId) {
    return _mixpanel.identify(userId);
  }

  @override
  Future<void> reset() {
    return _mixpanel.reset();
  }

  @override
  Future<void> setUserProperty({required String name, required Object value}) async {
    await _mixpanel.registerSuperProperties(<String, Object>{name: value});
    _mixpanel.getPeople().set(name, value);
  }

  @override
  Future<void> flush() {
    return _mixpanel.flush();
  }
}

class MixpanelAnalyticsProvider implements AnalyticsProvider {
  MixpanelAnalyticsProvider._(this._client, {bool hasIdentifiedUser = false, String? identifiedUserId})
    : _hasIdentifiedUser = hasIdentifiedUser,
      _identifiedUserId = identifiedUserId;

  final MixpanelClient _client;
  bool _hasIdentifiedUser;
  String? _identifiedUserId;

  static Future<MixpanelAnalyticsProvider> create({required String token, bool trackAutomaticEvents = false}) async {
    final Mixpanel mixpanel = await Mixpanel.init(token, trackAutomaticEvents: trackAutomaticEvents);
    final Map<Object?, Object?>? properties = await mixpanel.getSuperProperties();
    final bool hasIdentifiedUser = properties?['logged_in']?.toString() == '1';
    return MixpanelAnalyticsProvider._(
      MixpanelFlutterClient(mixpanel),
      hasIdentifiedUser: hasIdentifiedUser,
      identifiedUserId: hasIdentifiedUser ? await mixpanel.getDistinctId() : null,
    );
  }

  @visibleForTesting
  factory MixpanelAnalyticsProvider.forClient(
    MixpanelClient client, {
    bool hasIdentifiedUser = false,
    String? identifiedUserId,
  }) {
    return MixpanelAnalyticsProvider._(
      client,
      hasIdentifiedUser: hasIdentifiedUser,
      identifiedUserId: identifiedUserId,
    );
  }

  @override
  Future<void> logEvent({required String name, Map<String, Object> parameters = const <String, Object>{}}) async {
    await _client.track(name, properties: parameters.isEmpty ? null : parameters);
  }

  @override
  Future<void> setUserId(String? userId) async {
    final String trimmed = userId?.trim() ?? '';
    if (trimmed.isEmpty) {
      if (_hasIdentifiedUser) await _client.reset();
      _hasIdentifiedUser = false;
      _identifiedUserId = null;
      return;
    }
    if (_hasIdentifiedUser && _identifiedUserId != null && _identifiedUserId != trimmed) await _client.reset();
    await _client.identify(trimmed);
    _hasIdentifiedUser = true;
    _identifiedUserId = trimmed;
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
    await _client.setUserProperty(name: propertyName, value: propertyValue);
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
    await _client.track('screen_view', properties: properties);
  }

  @override
  Future<void> flush() {
    return _client.flush();
  }
}
