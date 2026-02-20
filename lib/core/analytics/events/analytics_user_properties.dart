enum AnalyticsUserProperty { subscriptionTier, isPremium }

extension AnalyticsUserPropertyX on AnalyticsUserProperty {
  String get wireName {
    switch (this) {
      case AnalyticsUserProperty.subscriptionTier:
        return 'subscription_tier';
      case AnalyticsUserProperty.isPremium:
        return 'is_premium';
    }
  }
}
