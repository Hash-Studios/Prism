import 'package:Prism/core/analytics/analytics_identity_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

void main() {
  group('AnalyticsIdentitySync', () {
    test('identifies logged in users and sets canonical traits', () async {
      final FakeAppAnalytics analytics = FakeAppAnalytics();
      final AnalyticsIdentitySync sync = AnalyticsIdentitySync(analytics: analytics);

      await sync.sync(
        loggedIn: true,
        userId: ' user_123 ',
        subscriptionTier: 'pro',
        isPremium: true,
        sourceTag: 'test_identify',
      );

      expect(analytics.userIds, <String?>['user_123']);
      expect(analytics.userProperties.map((entry) => '${entry.key}:${entry.value}').toList(), <String>[
        'subscription_tier:pro',
        'is_premium:1',
        'logged_in:1',
      ]);
    });

    test('resets to anonymous defaults for logged-out state', () async {
      final FakeAppAnalytics analytics = FakeAppAnalytics();
      final AnalyticsIdentitySync sync = AnalyticsIdentitySync(analytics: analytics);

      await sync.sync(
        loggedIn: false,
        userId: 'user_123',
        subscriptionTier: 'pro',
        isPremium: true,
        sourceTag: 'test_reset',
      );

      expect(analytics.userIds, <String?>[null]);
      expect(analytics.userProperties.map((entry) => '${entry.key}:${entry.value}').toList(), <String>[
        'subscription_tier:free',
        'is_premium:0',
        'logged_in:0',
      ]);
    });

    test('treats logged-in users without user id as anonymous', () async {
      final FakeAppAnalytics analytics = FakeAppAnalytics();
      final AnalyticsIdentitySync sync = AnalyticsIdentitySync(analytics: analytics);

      await sync.sync(
        loggedIn: true,
        userId: '   ',
        subscriptionTier: 'pro',
        isPremium: true,
        sourceTag: 'test_empty_id',
      );

      expect(analytics.userIds, <String?>[null]);
      expect(analytics.userProperties.map((entry) => '${entry.key}:${entry.value}').toList(), <String>[
        'subscription_tier:free',
        'is_premium:0',
        'logged_in:0',
      ]);
    });

    test('is idempotent for unchanged identity state', () async {
      final FakeAppAnalytics analytics = FakeAppAnalytics();
      final AnalyticsIdentitySync sync = AnalyticsIdentitySync(analytics: analytics);

      await sync.sync(
        loggedIn: true,
        userId: 'user_123',
        subscriptionTier: 'pro',
        isPremium: true,
        sourceTag: 'test_first',
      );
      await sync.sync(
        loggedIn: true,
        userId: 'user_123',
        subscriptionTier: 'pro',
        isPremium: true,
        sourceTag: 'test_second',
      );

      expect(analytics.userIds.length, 1);
      expect(analytics.userProperties.length, 3);

      await sync.sync(
        loggedIn: true,
        userId: 'user_123',
        subscriptionTier: 'pro',
        isPremium: false,
        sourceTag: 'test_state_change',
      );

      expect(analytics.userIds.length, 2);
      expect(analytics.userProperties.length, 6);
      expect(analytics.userProperties.last.key, 'logged_in');
      expect(analytics.userProperties.last.value, '1');
    });
  });
}
