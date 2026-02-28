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
  int flushCount = 0;
  final Map<String, Object> userProperties = <String, Object>{};

  @override
  void identify(String userId) {
    identifiedUsers.add(userId);
  }

  @override
  void reset() {
    resetCount += 1;
  }

  @override
  void setUserProperty({required String name, required Object value}) {
    userProperties[name] = value;
  }

  @override
  Future<void> flush() async {
    flushCount += 1;
  }

  @override
  void track(String eventName, {Map<String, Object>? properties}) {
    tracks.add(_TrackCall(eventName, properties));
  }
}

void main() {
  group('MixpanelAnalyticsProvider', () {
    test('tracks raw event payloads', () async {
      final _FakeMixpanelClient client = _FakeMixpanelClient();
      final MixpanelAnalyticsProvider provider = MixpanelAnalyticsProvider.forClient(client);

      await provider.logEvent(name: 'coin_earned', parameters: <String, Object>{'amount': 20});

      expect(client.tracks, hasLength(1));
      expect(client.tracks.single.eventName, 'coin_earned');
      expect(client.tracks.single.properties, <String, Object>{'amount': 20});
    });

    test('tracks canonical share/login/screen events', () async {
      final _FakeMixpanelClient client = _FakeMixpanelClient();
      final MixpanelAnalyticsProvider provider = MixpanelAnalyticsProvider.forClient(client);

      await provider.logShare(contentType: 'setup', itemId: 'id_1', method: 'link');
      await provider.logLogin(loginMethod: 'google');
      await provider.logScreenView(
        screenName: 'home',
        screenClass: 'HomeRoute',
        parameters: <String, Object>{'source': 'deeplink'},
      );

      expect(client.tracks[0].eventName, 'share');
      expect(client.tracks[0].properties, <String, Object>{
        'content_type': 'setup',
        'item_id': 'id_1',
        'method': 'link',
      });
      expect(client.tracks[1].eventName, 'login');
      expect(client.tracks[1].properties, <String, Object>{'login_method': 'google'});
      expect(client.tracks[2].eventName, 'screen_view');
      expect(client.tracks[2].properties, <String, Object>{
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
      expect(client.resetCount, 2);
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

    test('flush delegates to mixpanel client flush', () async {
      final _FakeMixpanelClient client = _FakeMixpanelClient();
      final MixpanelAnalyticsProvider provider = MixpanelAnalyticsProvider.forClient(client);

      await provider.flush();

      expect(client.flushCount, 1);
    });
  });
}
