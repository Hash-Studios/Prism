import 'package:flutter/material.dart';

/// Fades the top and bottom edges of a scrolling list into the background.
class OnboardingFadeMask extends StatelessWidget {
  const OnboardingFadeMask({super.key, required this.stops, required this.child});

  /// Gradient stops: fade in, fully visible from, fully visible to, fade out.
  final List<double> stops;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
        stops: stops,
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: Padding(padding: const EdgeInsets.all(1), child: child),
    );
  }
}
