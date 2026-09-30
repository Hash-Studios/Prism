import 'package:Prism/core/purchases/subscription_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromValue reads tier names case-insensitively and trims', () {
    expect(SubscriptionTier.fromValue('pro'), SubscriptionTier.pro);
    expect(SubscriptionTier.fromValue(' Lifetime '), SubscriptionTier.lifetime);
    expect(SubscriptionTier.fromValue('free'), SubscriptionTier.free);
  });

  test('fromValue falls back to free for unknown or missing values', () {
    expect(SubscriptionTier.fromValue(null), SubscriptionTier.free);
    expect(SubscriptionTier.fromValue(''), SubscriptionTier.free);
    expect(SubscriptionTier.fromValue('gold'), SubscriptionTier.free);
  });

  test('only free is unpaid', () {
    expect(SubscriptionTier.free.isPaid, isFalse);
    expect(SubscriptionTier.pro.isPaid, isTrue);
    expect(SubscriptionTier.lifetime.isPaid, isTrue);
  });
}
