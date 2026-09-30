import 'package:flutter/painting.dart';

class OnboardingAssets {
  const OnboardingAssets._();

  static const String wallpaperPrimary = 'assets/images/onboarding_bg_primary.jpg';

  /// A warm fill behind the welcome art so a failed decode cannot leave a white screen with a white button.
  static const Color fallbackFill = Color(0xFFF3C4B0);
}
