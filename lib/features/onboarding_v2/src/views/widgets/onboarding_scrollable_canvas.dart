import 'dart:math' as math;

import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:flutter/material.dart';

/// Gives the stacked layers at least [OnboardingLayout.minFrameHeight] (times the text scale) of height
/// and scrolls when the screen is shorter.
class OnboardingScrollableCanvas extends StatelessWidget {
  const OnboardingScrollableCanvas({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double textScale = math.max(1, media.textScaler.scale(10) / 10);
    return LayoutBuilder(
      builder: (context, constraints) {
        final double minHeight = OnboardingLayout.minFrameHeight * textScale + media.padding.vertical;
        final double height = math.max(constraints.maxHeight, minHeight);
        final bool scrolls = height > constraints.maxHeight;
        return SingleChildScrollView(
          physics: scrolls ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
          child: SizedBox(
            width: constraints.maxWidth,
            height: height,
            child: Stack(fit: StackFit.expand, children: children),
          ),
        );
      },
    );
  }
}
