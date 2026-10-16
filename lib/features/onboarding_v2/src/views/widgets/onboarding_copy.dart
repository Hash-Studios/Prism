import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';

class OnboardingHelperText extends StatelessWidget {
  const OnboardingHelperText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: OnboardingTypography.helper, textAlign: TextAlign.center);
}
