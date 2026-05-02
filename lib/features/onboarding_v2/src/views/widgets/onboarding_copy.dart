import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';

class OnboardingHeadline extends StatelessWidget {
  const OnboardingHeadline({super.key, required this.text, this.center = true});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: OnboardingTypography.headline, textAlign: center ? TextAlign.center : TextAlign.left);
  }
}

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
  const OnboardingHelperText({super.key, required this.text, this.width});

  final String text;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final child = Text(text, style: OnboardingTypography.helper, textAlign: TextAlign.center);
    if (width == null) {
      return child;
    }
    return SizedBox(width: width, child: child);
  }
}
