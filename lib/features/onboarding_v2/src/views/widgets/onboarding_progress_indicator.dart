import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';

class OnboardingProgressIndicator extends StatelessWidget {
  const OnboardingProgressIndicator({super.key, required this.step, this.color = OnboardingColors.progressActive});

  final int step;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final activeLeft = switch (step) {
      1 => 0.0,
      2 => OnboardingLayout.progressStepSpacing,
      _ => OnboardingLayout.progressTrailingSpacing,
    };
    final inactive = switch (step) {
      1 => const [OnboardingLayout.progressTrailingSpacing, OnboardingLayout.progressLastDotX],
      2 => const [0.0, OnboardingLayout.progressLastDotX],
      _ => const [0.0, OnboardingLayout.progressStepSpacing],
    };

    return SizedBox(
      width: OnboardingLayout.progressWidth,
      height: OnboardingLayout.progressHeight,
      child: Stack(
        children: [
          Positioned(
            left: inactive[0],
            top: 0,
            child: _Dot(active: false, wide: false, color: color),
          ),
          Positioned(
            left: inactive[1],
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
