/// Centralized RevenueCat identifiers.
/// Use these constants instead of inline strings throughout the app.
class PurchaseConstants {
  PurchaseConstants._();

  // Entitlements
  /// Lifetime one-time purchase.
  static const String entitlementPremium = 'prism_premium';

  /// Monthly/annual subscription.
  static const String entitlementUltra = 'prism_ultra';

  // Offering lookup keys
  /// Legacy lifetime offering (RC is_current: true for old app versions).
  /// Old live app uses this via offerings.current. Do not remove.
  static const String offeringDefault = 'default';

  /// Primary offering for new releases — monthly + annual subscription packages.
  /// Fetched by key directly so old app versions are not affected by RC is_current changes.
  static const String offeringUltra = 'ultra';

  /// Fallback hero image for paywall (used until metadata is added to RC).
  static const String defaultHeroImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/'
      'Replacement%20Thumbnails%2Fprism%20mock.png?alt=media&token=a86d1386-dbb5-493f-8399-ff0160b1a86a';

  /// Terms of Use / legal URL for paywall footer.
  static const String termsOfUseUrl = 'https://github.com/Hash-Studios/Prism/blob/master/PRIVACY.md';

  /// Sample wallpaper preview URLs shown as floating cards in the paywall hero.
  /// Replace these with your own premium wallpaper thumbnail URLs.
  static const List<String> previewWallpaperUrls = [
    'https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/'
        'Replacement%20Thumbnails%2Fprism%20mock.png?alt=media&token=a86d1386-dbb5-493f-8399-ff0160b1a86a',
    'https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/'
        'Replacement%20Thumbnails%2Fpost%20bg.png?alt=media&token=d708b5e3-a7ee-421b-beae-3b10946678c4',
    'https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/'
        'Replacement%20Thumbnails%2Fprism%20mock.png?alt=media&token=a86d1386-dbb5-493f-8399-ff0160b1a86a',
  ];
}
