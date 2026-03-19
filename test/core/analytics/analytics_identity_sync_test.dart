import 'package:Prism/core/analytics/analytics_identity_sync.dart';
import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAppAnalytics implements AppAnalytics {
  final List<String?> userIds = <String?>[];
  final List<MapEntry<String, String?>> userProperties = <MapEntry<String, String?>>[];

  @override
  List<NavigatorObserver> buildNavigatorObservers() => const <NavigatorObserver>[];

  @override
  Future<void> flush() async {}

  @override
  Future<void> logLogin({String? loginMethod}) async {}

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object?>? parameters,
  }) async {}

  @override
  Future<void> logShare({required String contentType, required String itemId, required String method}) async {}

  @override
  Future<void> setUserId(String? userId) async {
    userIds.add(userId);
  }

  @override
  Future<void> setUserProperty({required String name, String? value}) async {
    userProperties.add(MapEntry<String, String?>(name, value));
  }

  @override
  Future<void> track(AnalyticsEvent event) async {}
}

void main() {
  group('AnalyticsIdentitySync', () {
    test('identifies logged in users and sets canonical traits', () async {
      final _FakeAppAnalytics analytics = _FakeAppAnalytics();
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
      final _FakeAppAnalytics analytics = _FakeAppAnalytics();
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
      final _FakeAppAnalytics analytics = _FakeAppAnalytics();
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
      final _FakeAppAnalytics analytics = _FakeAppAnalytics();
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
