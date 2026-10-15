import 'dart:math' as math;

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';

class OnboardingSkipButton extends StatelessWidget {
  const OnboardingSkipButton({super.key, required this.sx, required this.sy, required this.color, required this.onTap});

  final double sx;
  final double sy;
  final Color color;
  final VoidCallback onTap;

  static const double _tapPadding = 12;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.only(
          top: math.max(0, OnboardingLayout.skipY * sy - _tapPadding),
          right: math.max(0, (OnboardingLayout.designWidth - OnboardingLayout.skipX - 32) * sx - _tapPadding),
        ),
        child: Semantics(
          button: true,
          label: 'Skip',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              PrismHaptics.tap();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(_tapPadding),
              child: Text('skip', style: OnboardingTypography.skip.copyWith(color: color)),
            ),
          ),
        ),
      ),
    );
  }
}
