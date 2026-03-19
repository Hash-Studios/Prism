class OnboardingV2Config {
  const OnboardingV2Config._();

  static const int minInterests = 5;
  static const int minFollows = 3;
  static const int paywallSoftGateSeconds = 4;
  static const int targetCreatorsCount = 10;
  static const int firstWallpaperValueTargetMs = 60000;

  static const String paywallPlacement = 'onboarding_completion';
  static const String paywallSource = 'onboarding_v2_last_step';
  static const String remoteConfigStarterPackKey = 'onboarding_starter_pack_v1';
  static const String remoteConfigV2EnabledKey = 'onboarding_v2_enabled';
  static const String excludedCategory = 'Community';
}
