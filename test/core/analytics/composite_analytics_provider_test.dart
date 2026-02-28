import 'package:Prism/core/analytics/providers/analytics_provider.dart';
import 'package:Prism/core/analytics/providers/composite_analytics_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingProvider implements AnalyticsProvider {
  final List<String> calls = <String>[];
  final List<String> eventNames = <String>[];
  final List<Map<String, Object>> eventParameters = <Map<String, Object>>[];
  final List<String?> userIds = <String?>[];
  final Map<String, String?> userProperties = <String, String?>{};

  @override
  Future<void> logEvent({required String name, Map<String, Object> parameters = const <String, Object>{}}) async {
    calls.add('log_event');
    eventNames.add(name);
    eventParameters.add(parameters);
  }

  @override
  Future<void> logLogin({String? loginMethod}) async {
    calls.add('log_login');
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
  }

  @override
  Future<void> logShare({required String contentType, required String itemId, required String method}) async {
    calls.add('log_share');
  }

  @override
  Future<void> flush() async {
    calls.add('flush');
  }
}

class _ThrowingProvider implements AnalyticsProvider {
  @override
  Future<void> logEvent({required String name, Map<String, Object> parameters = const <String, Object>{}}) =>
      Future<void>.error(StateError('boom'));

  @override
  Future<void> logLogin({String? loginMethod}) => Future<void>.error(StateError('boom'));

  @override
  Future<void> setUserId(String? userId) => Future<void>.error(StateError('boom'));

  @override
  Future<void> setUserProperty({required String name, String? value}) => Future<void>.error(StateError('boom'));

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object> parameters = const <String, Object>{},
  }) => Future<void>.error(StateError('boom'));

  @override
  Future<void> logShare({required String contentType, required String itemId, required String method}) =>
      Future<void>.error(StateError('boom'));

  @override
  Future<void> flush() => Future<void>.error(StateError('boom'));
}

void main() {
  test('continues dispatching when a provider throws', () async {
    final _RecordingProvider recording = _RecordingProvider();
    final CompositeAnalyticsProvider provider = CompositeAnalyticsProvider(<AnalyticsProvider>[
      _ThrowingProvider(),
      recording,
    ]);

    await provider.logEvent(name: 'coin_earned', parameters: <String, Object>{'amount': 5});

    expect(recording.eventNames, <String>['coin_earned']);
    expect(recording.eventParameters.single['amount'], 5);
  });

  test('fans out all analytics operations to each provider', () async {
    final _RecordingProvider first = _RecordingProvider();
    final _RecordingProvider second = _RecordingProvider();
    final CompositeAnalyticsProvider provider = CompositeAnalyticsProvider(<AnalyticsProvider>[first, second]);

    await provider.logEvent(name: 'paywall_result', parameters: <String, Object>{'result': 'success'});
    await provider.logShare(contentType: 'setup', itemId: 'item_1', method: 'link');
    await provider.logLogin(loginMethod: 'google');
    await provider.setUserId('u_1');
    await provider.setUserProperty(name: 'subscription_tier', value: 'pro');
    await provider.logScreenView(
      screenName: 'home',
      screenClass: 'HomeRoute',
      parameters: <String, Object>{'from_push': 1},
    );
    await provider.flush();

    expect(first.calls, <String>[
      'log_event',
      'log_share',
      'log_login',
      'set_user_id',
      'set_user_property',
      'log_screen_view',
      'flush',
    ]);
    expect(second.calls, <String>[
      'log_event',
      'log_share',
      'log_login',
      'set_user_id',
      'set_user_property',
      'log_screen_view',
      'flush',
    ]);
    expect(first.userIds.single, 'u_1');
    expect(first.userProperties['subscription_tier'], 'pro');
  });
}
