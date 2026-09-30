import 'dart:async';

import 'package:Prism/core/analytics/analytics_identity_sync.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
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

    test('serializes overlapping identity changes so the latest state wins', () async {
      final _BlockingIdentityAnalytics analytics = _BlockingIdentityAnalytics();
      final AnalyticsIdentitySync sync = AnalyticsIdentitySync(analytics: analytics);

      final Future<void> reset = sync.sync(
        loggedIn: false,
        userId: '',
        subscriptionTier: 'free',
        isPremium: false,
        sourceTag: 'test_reset',
      );
      await analytics.firstUserIdStarted.future;

      bool latestCompleted = false;
      final Future<void> identify = sync
          .sync(
            loggedIn: true,
            userId: 'user_123',
            subscriptionTier: 'pro',
            isPremium: true,
            sourceTag: 'test_identify',
          )
          .then((_) => latestCompleted = true);
      try {
        await Future<void>.delayed(Duration.zero);
        expect(latestCompleted, isFalse);
      } finally {
        if (!analytics.releaseFirstUserId.isCompleted) {
          analytics.releaseFirstUserId.complete();
        }
      }
      await Future.wait(<Future<void>>[reset, identify]);

      expect(analytics.userIds, <String?>[null, 'user_123']);
      expect(analytics.userProperties.map((entry) => '${entry.key}:${entry.value}').toList(), <String>[
        'subscription_tier:free',
        'is_premium:0',
        'logged_in:0',
        'subscription_tier:pro',
        'is_premium:1',
        'logged_in:1',
      ]);
    });

    test('serializes syncs across app-state owners sharing the runtime', () async {
      final _BlockingIdentityAnalytics analytics = _BlockingIdentityAnalytics();
      AnalyticsRuntime.instance = analytics;
      addTearDown(AnalyticsRuntime.reset);
      final AnalyticsIdentitySync oldOwner = AnalyticsIdentitySync();
      final AnalyticsIdentitySync restartedOwner = AnalyticsIdentitySync();

      final Future<void> oldState = oldOwner.sync(
        loggedIn: false,
        userId: '',
        subscriptionTier: 'free',
        isPremium: false,
        sourceTag: 'test_old_owner',
      );
      await analytics.firstUserIdStarted.future;
      bool restartedStateCompleted = false;
      final Future<void> restartedState = restartedOwner
          .sync(
            loggedIn: true,
            userId: 'user_123',
            subscriptionTier: 'pro',
            isPremium: true,
            sourceTag: 'test_restarted_owner',
          )
          .then((_) => restartedStateCompleted = true);
      try {
        await Future<void>.delayed(Duration.zero);
        expect(restartedStateCompleted, isFalse);
      } finally {
        if (!analytics.releaseFirstUserId.isCompleted) {
          analytics.releaseFirstUserId.complete();
        }
      }
      await Future.wait(<Future<void>>[oldState, restartedState]);

      expect(analytics.userIds, <String?>[null, 'user_123']);
      expect(analytics.userProperties.last.value, '1');
    });

    test('dedupes concurrent identical identity requests', () async {
      final _BlockingIdentityAnalytics analytics = _BlockingIdentityAnalytics();
      final AnalyticsIdentitySync sync = AnalyticsIdentitySync(analytics: analytics);

      final Future<void> first = sync.sync(
        loggedIn: true,
        userId: 'user_123',
        subscriptionTier: 'pro',
        isPremium: true,
        sourceTag: 'test_first',
      );
      await analytics.firstUserIdStarted.future;
      final Future<void> second = sync.sync(
        loggedIn: true,
        userId: 'user_123',
        subscriptionTier: 'pro',
        isPremium: true,
        sourceTag: 'test_second',
      );

      analytics.releaseFirstUserId.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(analytics.userIds, <String?>['user_123']);
      expect(analytics.userProperties, hasLength(3));
    });

    test('resolves the runtime analytics instance when a queued sync starts', () async {
      addTearDown(AnalyticsRuntime.reset);
      final _BlockingIdentityAnalytics oldRuntime = _BlockingIdentityAnalytics();
      AnalyticsRuntime.instance = oldRuntime;
      final AnalyticsIdentitySync sync = AnalyticsIdentitySync();

      final Future<void> first = sync.sync(
        loggedIn: true,
        userId: 'old_user',
        subscriptionTier: 'free',
        isPremium: false,
        sourceTag: 'test_old_runtime',
      );
      await oldRuntime.firstUserIdStarted.future;
      final Future<void> second = sync.sync(
        loggedIn: true,
        userId: 'new_user',
        subscriptionTier: 'pro',
        isPremium: true,
        sourceTag: 'test_new_runtime',
      );
      final FakeAppAnalytics newRuntime = FakeAppAnalytics();
      AnalyticsRuntime.instance = newRuntime;

      oldRuntime.releaseFirstUserId.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(oldRuntime.userIds, <String?>['old_user']);
      expect(newRuntime.userIds, <String?>['new_user']);
      expect(newRuntime.userProperties.last.value, '1');
    });

    test('continues processing identity changes after an analytics failure', () async {
      final _FailOnceIdentityAnalytics analytics = _FailOnceIdentityAnalytics();
      final AnalyticsIdentitySync sync = AnalyticsIdentitySync(analytics: analytics);

      await expectLater(
        sync.sync(
          loggedIn: true,
          userId: 'failed_user',
          subscriptionTier: 'pro',
          isPremium: true,
          sourceTag: 'test_failure',
        ),
        throwsStateError,
      );
      await sync.sync(
        loggedIn: true,
        userId: 'recovered_user',
        subscriptionTier: 'pro',
        isPremium: true,
        sourceTag: 'test_recovery',
      );

      expect(analytics.userIds, <String?>['recovered_user']);
      expect(analytics.userProperties, hasLength(3));
    });

    test('re-applies identity once the runtime analytics replaces the startup no-op', () async {
      addTearDown(AnalyticsRuntime.reset);
      AnalyticsRuntime.reset();
      final AnalyticsIdentitySync sync = AnalyticsIdentitySync();
      Future<void> syncUser() =>
          sync.sync(loggedIn: true, userId: 'user_123', subscriptionTier: 'pro', isPremium: true, sourceTag: 'test');

      await syncUser();
      final FakeAppAnalytics runtime = FakeAppAnalytics();
      AnalyticsRuntime.instance = runtime;
      await syncUser();
      await syncUser();

      expect(runtime.userIds, <String?>['user_123']);
    });

    test('runtime notifies listeners when the analytics instance changes', () {
      addTearDown(AnalyticsRuntime.reset);
      int notified = 0;
      void listener() => notified++;
      AnalyticsRuntime.changes.addListener(listener);
      addTearDown(() => AnalyticsRuntime.changes.removeListener(listener));

      AnalyticsRuntime.instance = FakeAppAnalytics();

      expect(notified, 1);
    });
  });
}

class _BlockingIdentityAnalytics extends FakeAppAnalytics {
  final Completer<void> firstUserIdStarted = Completer<void>();
  final Completer<void> releaseFirstUserId = Completer<void>();
  bool _blockFirstUserId = true;

  @override
  Future<void> setUserId(String? userId) async {
    await super.setUserId(userId);
    if (_blockFirstUserId) {
      _blockFirstUserId = false;
      firstUserIdStarted.complete();
      await releaseFirstUserId.future;
    }
  }
}

class _FailOnceIdentityAnalytics extends FakeAppAnalytics {
  bool _shouldFail = true;

  @override
  Future<void> setUserId(String? userId) async {
    if (_shouldFail) {
      _shouldFail = false;
      throw StateError('Expected test failure');
    }
    await super.setUserId(userId);
  }
}
