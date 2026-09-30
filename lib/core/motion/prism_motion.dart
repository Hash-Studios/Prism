import 'package:flutter/widgets.dart';

/// Shared animation durations. Pick the shortest one that still reads.
abstract final class PrismDurations {
  /// Press feedback (tap scale down). Must feel instant.
  static const Duration press = Duration(milliseconds: 100);

  /// Small state changes: tab switch, chip select, icon swap.
  static const Duration fast = Duration(milliseconds: 160);

  /// Default for entrances and most transitions: route push, fade and rise, empty states.
  static const Duration base = Duration(milliseconds: 240);

  /// Larger surfaces and emphasis: sheets, hero moves, big reveals.
  static const Duration slow = Duration(milliseconds: 320);

  /// One loop of a loading shimmer.
  static const Duration shimmer = Duration(milliseconds: 1400);
}

/// Shared easing curves.
abstract final class PrismCurves {
  /// Things that appear or arrive. Starts fast, ends soft.
  static const Curve enter = Curves.easeOutCubic;

  /// Things that leave or press down. Starts soft, ends fast.
  static const Curve exit = Curves.easeInCubic;

  /// Things that move from one place to another on screen.
  static const Curve move = Curves.easeInOutCubic;

  /// A small overshoot for playful pops (badges, success ticks). Use sparingly.
  static const Curve pop = Cubic(.34, 1.56, .64, 1);
}

extension PrismMotionContext on BuildContext {
  /// True when the system asks for less motion.
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  /// [d], or [Duration.zero] when the system asks for less motion.
  Duration motion(Duration d) => reduceMotion ? Duration.zero : d;
}
