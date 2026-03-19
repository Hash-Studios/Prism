import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:Prism/core/analytics/events/analytics_user_properties.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';

class AnalyticsIdentitySync {
  AnalyticsIdentitySync({required AppAnalytics analytics}) : _analytics = analytics;

  final AppAnalytics _analytics;
  _AnalyticsIdentityState? _lastAppliedState;

  Future<void> sync({
    required bool loggedIn,
    required String userId,
    required String subscriptionTier,
    required bool isPremium,
    required String sourceTag,
  }) async {
    final _AnalyticsIdentityState state = _AnalyticsIdentityState.fromRaw(
      loggedIn: loggedIn,
      userId: userId,
      subscriptionTier: subscriptionTier,
      isPremium: isPremium,
    );

    if (_lastAppliedState == state) {
      _logIdentitySync(
        message: 'Analytics identity sync skipped; state unchanged.',
        sourceTag: sourceTag,
        action: 'noop',
        state: state,
      );
      return;
    }

    if (!state.isIdentified) {
      await _analytics.setUserId(null);
      await _analytics.setUserProperty(name: AnalyticsUserProperty.subscriptionTier.wireName, value: 'free');
      await _analytics.setUserProperty(name: AnalyticsUserProperty.isPremium.wireName, value: '0');
      await _analytics.setUserProperty(name: AnalyticsUserProperty.loggedIn.wireName, value: '0');
      _lastAppliedState = state;
      _logIdentitySync(
        message: 'Analytics identity reset applied.',
        sourceTag: sourceTag,
        action: 'reset',
        state: state,
      );
      return;
    }

    await _analytics.setUserId(state.userId);
    await _analytics.setUserProperty(
      name: AnalyticsUserProperty.subscriptionTier.wireName,
      value: state.subscriptionTier,
    );
    await _analytics.setUserProperty(
      name: AnalyticsUserProperty.isPremium.wireName,
      value: state.isPremium ? '1' : '0',
    );
    await _analytics.setUserProperty(name: AnalyticsUserProperty.loggedIn.wireName, value: '1');
    _lastAppliedState = state;
    _logIdentitySync(
      message: 'Analytics identity identify applied.',
      sourceTag: sourceTag,
      action: 'identify',
      state: state,
    );
  }

  @visibleForTesting
  void resetCache() {
    _lastAppliedState = null;
  }

  void _logIdentitySync({
    required String message,
    required String sourceTag,
    required String action,
    required _AnalyticsIdentityState state,
  }) {
    if (kReleaseMode) {
      return;
    }
    logger.d(
      message,
      tag: 'AnalyticsIdentity',
      fields: <String, Object?>{
        'source_tag': sourceTag,
        'action': action,
        'identified': state.isIdentified,
        if (state.isIdentified) 'user_id': state.userId,
        'subscription_tier': state.subscriptionTier,
        'is_premium': state.isPremium ? 1 : 0,
        'logged_in': state.isIdentified ? 1 : 0,
      },
    );
  }
}

class _AnalyticsIdentityState {
  const _AnalyticsIdentityState({
    required this.isIdentified,
    required this.userId,
    required this.subscriptionTier,
    required this.isPremium,
  });

  final bool isIdentified;
  final String userId;
  final String subscriptionTier;
  final bool isPremium;

  factory _AnalyticsIdentityState.fromRaw({
    required bool loggedIn,
    required String userId,
    required String subscriptionTier,
    required bool isPremium,
  }) {
    final String normalizedUserId = userId.trim();
    final String normalizedTier = subscriptionTier.trim().isEmpty ? 'free' : subscriptionTier.trim();
    final bool shouldIdentify = loggedIn && normalizedUserId.isNotEmpty;

    if (!shouldIdentify) {
      return const _AnalyticsIdentityState(isIdentified: false, userId: '', subscriptionTier: 'free', isPremium: false);
    }

    return _AnalyticsIdentityState(
      isIdentified: true,
      userId: normalizedUserId,
      subscriptionTier: normalizedTier,
      isPremium: isPremium,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _AnalyticsIdentityState &&
        other.isIdentified == isIdentified &&
        other.userId == userId &&
        other.subscriptionTier == subscriptionTier &&
        other.isPremium == isPremium;
  }

  @override
  int get hashCode => Object.hash(isIdentified, userId, subscriptionTier, isPremium);
}
