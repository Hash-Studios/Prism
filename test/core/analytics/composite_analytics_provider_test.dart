import 'package:Prism/core/analytics/providers/analytics_provider.dart';
import 'package:Prism/core/analytics/providers/composite_analytics_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/recording_analytics_provider.dart';

class _ThrowingProvider implements AnalyticsProvider {
  @override
  Future<void> logEvent({required String name, Map<String, Object> parameters = const <String, Object>{}}) =>
      Future<void>.error(StateError('boom'));

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
  Future<void> flush() => Future<void>.error(StateError('boom'));
}

void main() {
  test('continues dispatching when a provider throws', () async {
    final RecordingAnalyticsProvider recording = RecordingAnalyticsProvider();
    final CompositeAnalyticsProvider provider = CompositeAnalyticsProvider(<AnalyticsProvider>[
      _ThrowingProvider(),
      recording,
    ], logProviderFailures: false);

    await provider.logEvent(name: 'coin_earned', parameters: <String, Object>{'amount': 5});

    expect(recording.events.single.name, 'coin_earned');
    expect(recording.events.single.parameters['amount'], 5);
  });

  test('fans out all analytics operations to each provider', () async {
    final RecordingAnalyticsProvider first = RecordingAnalyticsProvider();
    final RecordingAnalyticsProvider second = RecordingAnalyticsProvider();
    final CompositeAnalyticsProvider provider = CompositeAnalyticsProvider(<AnalyticsProvider>[
      first,
      second,
    ], logProviderFailures: false);

    await provider.logEvent(name: 'paywall_result', parameters: <String, Object>{'result': 'success'});
    await provider.setUserId('u_1');
    await provider.setUserProperty(name: 'subscription_tier', value: 'pro');
    await provider.logScreenView(
      screenName: 'home',
      screenClass: 'HomeRoute',
      parameters: <String, Object>{'from_push': 1},
    );
    await provider.flush();

    const List<String> expectedCalls = <String>[
      'log_event',
      'set_user_id',
      'set_user_property',
      'log_screen_view',
      'flush',
    ];
    expect(first.calls, expectedCalls);
    expect(second.calls, expectedCalls);
    expect(first.userIds.single, 'u_1');
    expect(first.userProperties['subscription_tier'], 'pro');
  });
}
