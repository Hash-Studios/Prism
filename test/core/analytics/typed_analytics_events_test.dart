import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/recording_analytics_provider.dart';

void main() {
  test('coin_earned serializes the domain action wire value', () {
    const CoinEarnedEvent event = CoinEarnedEvent(
      action: CoinEarnAction.rewardedAd,
      amount: 10,
      balance: 20,
      sourceTag: 'coins.rewarded_ad',
    );

    expect(event.toWireParameters(), <String, Object?>{
      'action': 'rewarded_ad',
      'amount': 10,
      'balance': 20,
      'source_tag': 'coins.rewarded_ad',
    });
  });

  group('provider-backed track dispatch', () {
    test('dispatches typed event via provider.logEvent', () async {
      final RecordingAnalyticsProvider provider = RecordingAnalyticsProvider();
      final ProviderBackedAppAnalytics analytics = ProviderBackedAppAnalytics(provider: provider);

      await analytics.track(const CollectionsCheckedEvent());

      expect(provider.events.single.name, 'collections_checked');
      expect(provider.events.single.parameters, <String, Object>{});
    });

    test('normalizes screen views before dispatch', () async {
      final RecordingAnalyticsProvider provider = RecordingAnalyticsProvider();
      final ProviderBackedAppAnalytics analytics = ProviderBackedAppAnalytics(provider: provider);

      await analytics.logScreenView(screenName: '/HomeFeed', screenClass: 'HomeRoute');

      expect(provider.screenViews.single.name, 'home_feed');
      expect(provider.screenViews.single.screenClass, 'HomeRoute');
    });
  });
}
