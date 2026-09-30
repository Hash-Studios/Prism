import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';

class OnboardingBodyText extends StatelessWidget {
  const OnboardingBodyText({super.key, required this.text, this.center = true});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: OnboardingTypography.body, textAlign: center ? TextAlign.center : TextAlign.left);
  }
}

class OnboardingHelperText extends StatelessWidget {
  const OnboardingHelperText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: OnboardingTypography.helper, textAlign: TextAlign.center);
}
