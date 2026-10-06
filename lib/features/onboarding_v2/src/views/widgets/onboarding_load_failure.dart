import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';

/// Shown in place of an empty list so a failed load never leaves the user waiting on a spinner.
class OnboardingLoadFailure extends StatelessWidget {
  const OnboardingLoadFailure({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: OnboardingTypography.body, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              PrismHaptics.tap();
              onRetry();
            },
            child: Text(
              'Try again',
              style: OnboardingTypography.body.copyWith(
                color: OnboardingColors.textOnDark,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
