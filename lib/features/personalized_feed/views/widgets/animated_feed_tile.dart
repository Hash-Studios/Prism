import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedFeedTile extends StatelessWidget {
  const AnimatedFeedTile({super.key, required this.index, required this.child, required this.reduceMotion});

  final int index;
  final Widget child;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final delay = math.min(index, 10) * 28;
    final duration = reduceMotion ? Duration.zero : Duration(milliseconds: 300 + delay);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, (1 - value) * 16), child: child),
        );
      },
      child: child,
    );
  }
}
