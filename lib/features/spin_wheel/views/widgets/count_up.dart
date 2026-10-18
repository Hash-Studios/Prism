import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';

/// "+N" counting up from 0, then [suffix]. Under reduced motion it shows the number at once.
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, required this.style, this.suffix = ''});

  final int value;
  final String suffix;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: context.reduceMotion ? 1 : 0, end: 1),
      duration: context.motion(PrismDurations.slow * 2),
      curve: PrismCurves.enter,
      builder: (BuildContext context, double t, Widget? _) => Text('+${(value * t).round()}$suffix', style: style),
    );
  }
}
