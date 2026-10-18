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

  test('spin_wheel_spun serializes the spin and the earn and spend wire values', () {
    const SpinWheelSpunEvent event = SpinWheelSpunEvent(
      free: false,
      cost: 10,
      segment: 3,
      prize: 'coins',
      coins: 100,
      xp: 0,
    );

    expect(event.eventName, 'spin_wheel_spun');
    expect(event.toWireParameters(), <String, Object?>{
      'free': 0,
      'cost': 10,
      'segment': 3,
      'prize': 'coins',
      'coins': 100,
      'xp': 0,
    });
    expect(
      const CoinEarnedEvent(
        action: CoinEarnAction.spinWheel,
        amount: 100,
        balance: 190,
        sourceTag: 'coins.spin_wheel',
      ).toWireParameters()['action'],
      'spin_wheel',
    );
    expect(
      const CoinSpentEvent(
        action: CoinSpendAction.spinWheel,
        amount: 10,
        balance: 90,
        sourceTag: 'coins.spin_wheel',
      ).toWireParameters()['action'],
      'spin_wheel',
    );
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
