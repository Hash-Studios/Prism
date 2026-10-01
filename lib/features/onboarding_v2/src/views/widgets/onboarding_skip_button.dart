import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';

class OnboardingSkipButton extends StatelessWidget {
  const OnboardingSkipButton({super.key, required this.sx, required this.sy, required this.color, required this.onTap});

  final double sx;
  final double sy;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.only(
          top: OnboardingLayout.skipY * sy,
          right: (OnboardingLayout.designWidth - OnboardingLayout.skipX - 32) * sx,
        ),
        child: GestureDetector(
          onTap: () {
            PrismHaptics.tap();
            onTap();
          },
          child: Text('skip', style: OnboardingTypography.skip.copyWith(color: color)),
        ),
      ),
    );
  }
}
