import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';

typedef OnboardingFrameBuilder = Widget Function(BuildContext context, double sx, double sy);

class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({super.key, required this.builder});

  final OnboardingFrameBuilder builder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sx = constraints.maxWidth / OnboardingLayout.designWidth;
          final sy = constraints.maxHeight / OnboardingLayout.designHeight;
          return builder(context, sx, sy);
        },
      ),
    );
  }
}
