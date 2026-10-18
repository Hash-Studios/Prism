import 'dart:math' as math;

import 'package:Prism/features/spin_wheel/domain/wheel_motion.dart';

/// The pointer's flapper: a spring that a peg pushes aside and that snaps back.
///
/// The pegs sit at the slice boundaries, `theta = k * s` puts peg `k` under the pointer. A peg meets the tip
/// [contactAngle] before the pointer axis, drags it along the spin direction, and slips past [releaseAngle] after the
/// axis. A fast wheel crosses that window in less than a frame, so a peg that was released inside a frame counts as a
/// full push. After the release the flapper is a damped spring.
class PointerFlapper {
  /// Radians the peg travels while it holds the tip, before the axis.
  static const double contactAngle = 0.07;

  /// Radians the peg travels while it holds the tip, after the axis.
  static const double releaseAngle = 0.07;

  /// The most the tip swings, in radians. Positive is along the spin direction.
  static const double maxAngle = 0.62;

  static const double _naturalFrequency = 2 * math.pi * 11;
  static const double _damping = 0.34;
  static const double _maxStep = 0.004;

  /// Swing of the flapper in radians. Positive follows the wheel.
  double angle = 0;
  double _angularVelocity = 0;

  /// Moves the flapper by [dt] seconds while the wheel goes from [fromTheta] to [toTheta] with [count] slices.
  ///
  /// Returns the number of pegs that passed the pointer in this step.
  int update(double dt, double fromTheta, double toTheta, int count) {
    final double s = sliceWidth(count);
    final double from = fromTheta / s;
    final double to = toTheta / s;
    final int passes = to > from ? to.floor() - from.floor() : 0;
    final double releaseAt = releaseAngle / s;
    final bool forward = to > from;
    final bool released = forward && (to - releaseAt).floor() > (from - releaseAt).floor();
    final double offset = (to - to.roundToDouble()) * s;
    final bool held = forward && offset >= -contactAngle && offset <= releaseAngle;
    if (released) {
      angle = maxAngle;
      _angularVelocity = 0;
    } else if (held) {
      final double pushed = maxAngle * (offset + contactAngle) / (contactAngle + releaseAngle);
      if (pushed > angle) {
        angle = pushed;
        _angularVelocity = 0;
      }
    }
    if (!held) _spring(dt);
    return passes;
  }

  void _spring(double dt) {
    double remaining = dt;
    while (remaining > 0) {
      final double h = math.min(remaining, _maxStep);
      final double accel =
          -_naturalFrequency * _naturalFrequency * angle - 2 * _damping * _naturalFrequency * _angularVelocity;
      _angularVelocity += accel * h;
      angle += _angularVelocity * h;
      remaining -= h;
    }
    angle = angle.clamp(-maxAngle, maxAngle);
  }

  void reset() {
    angle = 0;
    _angularVelocity = 0;
  }
}
