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
  });

  final String topImageLink;
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
}
