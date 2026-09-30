enum SubscriptionTier {
  free,
  pro,
  lifetime;

  bool get isPaid => this != SubscriptionTier.free;

  static SubscriptionTier fromValue(String? raw) =>
      SubscriptionTier.values.asNameMap()[(raw ?? '').trim().toLowerCase()] ?? SubscriptionTier.free;
}
