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

  test('daily_chest_opened serializes the chest and the quest_chest spend wire value', () {
    const DailyChestOpenedEvent event = DailyChestOpenedEvent(
      free: true,
      cost: 0,
      slot: 6,
      prize: 'coins',
      tier: 'legendary',
      coins: 200,
      xp: 0,
      doubled: true,
    );

    expect(event.eventName, 'daily_chest_opened');
    expect(event.toWireParameters(), <String, Object?>{
      'free': 1,
      'cost': 0,
      'slot': 6,
      'prize': 'coins',
      'tier': 'legendary',
      'coins': 200,
      'xp': 0,
      'doubled': 1,
    });
    expect(
      const CoinSpentEvent(
        action: CoinSpendAction.questChest,
        amount: 8,
        balance: 92,
        sourceTag: 'coins.daily_chest',
      ).toWireParameters()['action'],
      'quest_chest',
    );
  });

  group('provider-backed track dispatch', () {
    test('dispatches typed event via provider.logEvent', () async {
      final RecordingAnalyticsProvider provider = RecordingAnalyticsProvider();
      final ProviderBackedAppAnalytics analytics = ProviderBackedAppAnalytics(provider: provider);

      await analytics.track(const CollectionsCheckedEvent());

      expect(provider.events.single.name, 'collections_checked');
      final Map<String, Object> parameters = provider.events.single.parameters;
      expect(parameters['analytics_session_id'], isA<String>().having((String id) => id.isNotEmpty, 'nonempty', true));
      expect(parameters['analytics_schema_version'], 2);
      await analytics.logScreenView(screenName: 'home');
      expect(provider.screenViews.single.parameters['analytics_session_id'], parameters['analytics_session_id']);
      final ProviderBackedAppAnalytics next = ProviderBackedAppAnalytics(provider: provider);
      await next.track(const CollectionsCheckedEvent());
      expect(provider.events.last.parameters['analytics_session_id'], isNot(parameters['analytics_session_id']));
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
