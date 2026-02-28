enum AnalyticsUserProperty { subscriptionTier, isPremium, loggedIn }

extension AnalyticsUserPropertyX on AnalyticsUserProperty {
  String get wireName {
    switch (this) {
      case AnalyticsUserProperty.subscriptionTier:
        return 'subscription_tier';
      case AnalyticsUserProperty.isPremium:
        return 'is_premium';
      case AnalyticsUserProperty.loggedIn:
        return 'logged_in';
    }
  }
}
