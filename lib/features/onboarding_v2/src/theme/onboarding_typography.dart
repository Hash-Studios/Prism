import 'package:Prism/features/onboarding_v2/src/theme/onboarding_colors.dart';
import 'package:flutter/material.dart';

class OnboardingTypography {
  const OnboardingTypography._();

  static const String serif = 'Fraunces';
  static const String sans = 'Satoshi';

  static const TextStyle logo = TextStyle(
    fontFamily: serif,
    fontSize: 18,
    height: 1.233,
    fontWeight: FontWeight.w900,
    color: OnboardingColors.textPrimary,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: serif,
    fontSize: 40,
    height: 1.233,
    fontWeight: FontWeight.w400,
    color: OnboardingColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: sans,
    fontSize: 16,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: OnboardingColors.textPrimary,
  );

  static const TextStyle cta = TextStyle(
    fontFamily: serif,
    fontSize: 16,
    height: 1.233,
    fontWeight: FontWeight.w400,
    color: OnboardingColors.buttonText,
  );

  static const TextStyle helper = TextStyle(
    fontFamily: sans,
    fontSize: 11,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: OnboardingColors.textOnDark,
  );

  static const TextStyle skip = TextStyle(
    fontFamily: serif,
    fontSize: 16,
    height: 1.233,
    fontWeight: FontWeight.w400,
    color: OnboardingColors.textPrimary,
  );
}
