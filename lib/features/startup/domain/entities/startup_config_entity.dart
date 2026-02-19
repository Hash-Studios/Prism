class StartupConfigEntity {
  const StartupConfigEntity({
    required this.topImageLink,
    required this.bannerText,
    required this.bannerTextOn,
    required this.bannerUrl,
    required this.obsoleteAppVersion,
    required this.verifiedUsers,
    required this.premiumCollections,
    required this.topTitleText,
    required this.categories,
    required this.followersTab,
    required this.aiEnabled,
    required this.aiRolloutPercent,
    required this.aiSubmitEnabled,
    required this.aiVariationsEnabled,
    required this.useRcPaywalls,
  });

  final String topImageLink;
  final String bannerText;
  final String bannerTextOn;
  final String bannerUrl;
  final String obsoleteAppVersion;
  final List<String> verifiedUsers;
  final List<String> premiumCollections;
  final List<String> topTitleText;
  final List<Map<String, dynamic>> categories;
  final bool followersTab;
  final bool aiEnabled;
  final int aiRolloutPercent;
  final bool aiSubmitEnabled;
  final bool aiVariationsEnabled;
  final bool useRcPaywalls;
}
