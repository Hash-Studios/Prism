import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';

class OnboardingProgressIndicator extends StatelessWidget {
  const OnboardingProgressIndicator({
    super.key,
    required this.step,
    this.totalSteps = 3,
    this.color = OnboardingColors.progressActive,
  });

  final int step;

  /// Total number of steps shown as dots. Defaults to 3 for backward compat.
  final int totalSteps;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Each dot is spaced progressStepSpacing apart: 0, 16, 32, 48 for 4 steps.
    final activeLeft = (step - 1) * OnboardingLayout.progressStepSpacing;
    final inactivePositions = <double>[
      for (int i = 0; i < totalSteps; i++)
        if (i != step - 1) i * OnboardingLayout.progressStepSpacing,
    ];

    return SizedBox(
      width: OnboardingLayout.progressWidth,
      height: OnboardingLayout.progressHeight,
      child: Stack(
        children: [
          for (final left in inactivePositions)
            Positioned(
              left: left,
              top: 0,
              child: _Dot(active: false, wide: false, color: color),
            ),
          Positioned(
            left: activeLeft,
            top: 0,
            child: _Dot(active: true, wide: true, color: color),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active, required this.wide, required this.color});

  final bool active;
  final bool wide;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: OnboardingMotion.normal,
      curve: OnboardingMotion.emphasized,
      width: wide ? OnboardingLayout.progressActiveWidth : OnboardingLayout.progressDotSize,
      height: OnboardingLayout.progressDotSize,
      decoration: BoxDecoration(
        color: active ? color : color.withValues(alpha: OnboardingOpacity.progressInactive),
        borderRadius: BorderRadius.circular(OnboardingRadius.dot),
      ),
    );
  }
}
