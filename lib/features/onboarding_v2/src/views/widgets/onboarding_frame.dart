import 'dart:math' as math;

import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';

typedef OnboardingFrameBuilder = Widget Function(BuildContext context, double sx, double sy);

/// Lays the fixed design out in a centred column. Horizontal scale never exceeds the vertical scale,
/// so tiles stay square and wide screens keep a column no wider than [OnboardingLayout.maxContentWidth].
class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({super.key, required this.builder});

  final OnboardingFrameBuilder builder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sy = constraints.maxHeight / OnboardingLayout.designHeight;
          final sx = math.min(
            math.min(constraints.maxWidth, OnboardingLayout.maxContentWidth) / OnboardingLayout.designWidth,
            sy,
          );
          return Center(
            child: SizedBox(
              width: OnboardingLayout.designWidth * sx,
              height: constraints.maxHeight,
              child: builder(context, sx, sy),
            ),
          );
        },
      ),
    );
  }
}
