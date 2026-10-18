import 'package:Prism/core/analytics/providers/mixpanel_analytics_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _TrackCall {
  const _TrackCall(this.eventName, this.properties);

  final String eventName;
  final Map<String, Object>? properties;
}

class _FakeMixpanelClient implements MixpanelClient {
  final List<_TrackCall> tracks = <_TrackCall>[];
  final List<String> identifiedUsers = <String>[];
  int resetCount = 0;
  final Map<String, Object> userProperties = <String, Object>{};

  @override
  Future<void> identify(String userId) async {
    identifiedUsers.add(userId);
  }

  @override
  Future<void> reset() async {
    resetCount += 1;
  }

  @override
  Future<void> setUserProperty({required String name, required Object value}) async {
    userProperties[name] = value;
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> track(String eventName, {Map<String, Object>? properties}) async {
    tracks.add(_TrackCall(eventName, properties));
  }
}

void main() {
  group('MixpanelAnalyticsProvider', () {
    test('cold guest preserves anonymous identity and clears persisted signed identity once', () async {
      final _FakeMixpanelClient anonymous = _FakeMixpanelClient();
      await MixpanelAnalyticsProvider.forClient(anonymous).setUserId(null);
      expect(anonymous.resetCount, 0);
      final _FakeMixpanelClient signed = _FakeMixpanelClient();
      final MixpanelAnalyticsProvider provider = MixpanelAnalyticsProvider.forClient(signed, hasIdentifiedUser: true);
      await provider.setUserId(null);
      await provider.setUserId(null);
      expect(signed.resetCount, 1);
    });

    test('signed startup retains identity until logout', () async {
      final _FakeMixpanelClient client = _FakeMixpanelClient();
      final MixpanelAnalyticsProvider provider = MixpanelAnalyticsProvider.forClient(
        client,
        hasIdentifiedUser: true,
        identifiedUserId: 'same_user',
      );
      await provider.setUserId('same_user');
      expect(client.resetCount, 0);
      await provider.setUserId(null);
      expect(client.resetCount, 1);
    });

    test('cold account switch resets persisted account before identification', () async {
      final _FakeMixpanelClient client = _FakeMixpanelClient();
      final MixpanelAnalyticsProvider provider = MixpanelAnalyticsProvider.forClient(
        client,
        hasIdentifiedUser: true,
        identifiedUserId: 'account_a',
      );
      await provider.setUserId('account_b');
      expect(client.resetCount, 1);
      expect(client.identifiedUsers, <String>['account_b']);
    });
    test('tracks raw event payloads', () async {
      final _FakeMixpanelClient client = _FakeMixpanelClient();
      final MixpanelAnalyticsProvider provider = MixpanelAnalyticsProvider.forClient(client);

      await provider.logEvent(name: 'coin_earned', parameters: <String, Object>{'amount': 20});

      expect(client.tracks, hasLength(1));
      expect(client.tracks.single.eventName, 'coin_earned');
      expect(client.tracks.single.properties, <String, Object>{'amount': 20});
    });

    test('tracks screen views as screen_view events', () async {
      final _FakeMixpanelClient client = _FakeMixpanelClient();
      final MixpanelAnalyticsProvider provider = MixpanelAnalyticsProvider.forClient(client);

      await provider.logScreenView(
        screenName: 'home',
        screenClass: 'HomeRoute',
        parameters: <String, Object>{'source': 'deeplink'},
      );

      expect(client.tracks.single.eventName, 'screen_view');
      expect(client.tracks.single.properties, <String, Object>{
        'screen_name': 'home',
        'screen_class': 'HomeRoute',
        'source': 'deeplink',
      });
    });

    test('identify/reset routing is based on user id', () async {
      final _FakeMixpanelClient client = _FakeMixpanelClient();
      final MixpanelAnalyticsProvider provider = MixpanelAnalyticsProvider.forClient(client);

      await provider.setUserId('user_123');
      await provider.setUserId('   ');
      await provider.setUserId(null);

      expect(client.identifiedUsers, <String>['user_123']);
      expect(client.resetCount, 1);
    });

    test('ignores empty user properties and sets valid ones', () async {
      final _FakeMixpanelClient client = _FakeMixpanelClient();
      final MixpanelAnalyticsProvider provider = MixpanelAnalyticsProvider.forClient(client);

      await provider.setUserProperty(name: 'subscription_tier', value: 'pro');
      await provider.setUserProperty(name: 'is_premium', value: '');
      await provider.setUserProperty(name: ' ', value: '1');
      await provider.setUserProperty(name: 'is_premium');

      expect(client.userProperties, <String, Object>{'subscription_tier': 'pro'});
    });
  });
}
