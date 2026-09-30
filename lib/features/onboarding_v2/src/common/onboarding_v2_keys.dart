import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';

class OnboardingV2Keys {
  const OnboardingV2Keys._();

  static const String onboardedNew = 'onboarded_v2_new';
  static const String selectedInterests = 'onboarding_v2_interests';
  static const String followedCreators = 'onboarding_v2_followed_creators';
}

/// Sends the user back through onboarding on their next launch.
Future<void> resetOnboardingLocalState(SettingsLocalDataSource settings) => Future.wait(<Future<void>>[
  settings.set(OnboardingV2Keys.onboardedNew, false),
  settings.set(OnboardingV2Keys.selectedInterests, ''),
  settings.set(OnboardingV2Keys.followedCreators, ''),
]);
