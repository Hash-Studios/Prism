enum SubscriptionTier {
  free,
  pro,
  lifetime;

  bool get isPaid => this != SubscriptionTier.free;

  String get value {
    switch (this) {
      case SubscriptionTier.free:
        return 'free';
      case SubscriptionTier.pro:
        return 'pro';
      case SubscriptionTier.lifetime:
        return 'lifetime';
    }
  }

  static SubscriptionTier fromValue(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'pro':
        return SubscriptionTier.pro;
      case 'lifetime':
        return SubscriptionTier.lifetime;
      case 'free':
      default:
        return SubscriptionTier.free;
    }
  }
}
