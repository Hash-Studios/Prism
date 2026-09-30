/// Centralized RevenueCat identifiers.
/// Use these constants instead of inline strings throughout the app.
class PurchaseConstants {
  PurchaseConstants._();

  // Entitlements
  /// Canonical v3 entitlement used by RC paywalls and new product mapping.
  static const String entitlementV3ProAccess = 'prism_v3_pro_access';

  /// Lifetime one-time purchase.
  static const String entitlementPremium = 'prism_premium';

  /// Monthly/annual subscription.
  static const String entitlementUltra = 'prism_ultra';

  /// Legacy one-time purchase.
  static const String entitlementPro = 'prism_pro';

  /// Legacy paid collections entitlement.
  static const String entitlementCollections = 'prism_collections';

  static const List<String> paidEntitlementKeys = <String>[
    entitlementV3ProAccess,
    entitlementUltra,
    entitlementPremium,
    entitlementPro,
    entitlementCollections,
  ];

  // Offering lookup keys
  /// Legacy lifetime offering (RC is_current: true for old app versions).
  /// Old live app uses this via offerings.current. Do not remove.
  static const String offeringDefault = 'default';

  /// Primary offering for new releases — monthly + annual subscription packages.
  /// Fetched by key directly so old app versions are not affected by RC is_current changes.
  static const String offeringUltra = 'ultra';

  /// Canonical v3 offering containing monthly/annual/lifetime packages.
  static const String offeringV3Default = 'v3_default';
}
