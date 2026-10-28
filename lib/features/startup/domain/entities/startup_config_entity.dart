class StartupConfigEntity {
  const StartupConfigEntity({
    required this.topImageLink,
    required this.bannerText,
    required this.bannerTextOn,
    required this.bannerUrl,
    required this.obsoleteAppVersion,
    required this.verifiedUsers,
    required this.premiumCollections,
    required this.aiEnabled,
    required this.aiRolloutPercent,
    required this.aiSubmitEnabled,
    required this.aiVariationsEnabled,
    required this.useRcPaywalls,
    required this.onboardingV2Enabled,
    this.minStoreBuild = 0,
    this.storeUpdateBlocking = false,
  });

  final String topImageLink;

  /// Remote campaign copy. Empty means the UI should use its localized default.
  final String bannerText;
  final bool bannerTextOn;
  final String bannerUrl;
  final String obsoleteAppVersion;
  final List<String> verifiedUsers;
  final List<String> premiumCollections;
  final bool aiEnabled;
  final int aiRolloutPercent;
  final bool aiSubmitEnabled;
  final bool aiVariationsEnabled;
  final bool useRcPaywalls;
  final bool onboardingV2Enabled;

  /// Remote Config minimum build for this platform. 0 means no minimum.
  final int minStoreBuild;
  final bool storeUpdateBlocking;
}
