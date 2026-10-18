import 'dart:math' as math;

import 'package:Prism/features/spin_wheel/domain/wheel_motion.dart';

enum WheelPhase {
  /// At rest before a spin.
  idle,

  /// A short wind back against the spin direction.
  windUp,

  /// Speeding up to the cruise speed.
  spinUp,

  /// Turning at the cruise speed until the server replies.
  cruise,

  /// The quartic ease-out onto the winning slice.
  landing,

  /// An ease to a stop after a refusal or a failure.
  stopping,

  /// Stopped on the winning slice.
  landed,
}

/// The wheel's motion over time. It is pure: the caller feeds it the elapsed seconds of one ticker, so one clock drives
/// every phase and there are no chained tweens.
///
/// Timeline of one spin: wind back [windUpAngle] over [windUpSeconds], speed up to [cruiseSpeed] over [spinUpSeconds],
/// cruise for at least [minCruiseSeconds] and until [land] is called, then ease out onto the target.
class WheelSpinner {
  WheelSpinner({this.theta = 0, this.cruiseSpeed = defaultCruiseSpeed});

  /// 2.6 turns a second.
  static const double defaultCruiseSpeed = 2.6 * wheelTurn;
  static const double windUpAngle = 0.12;
  static const double windUpSeconds = 0.16;
  static const double spinUpSeconds = 0.5;
  static const double minCruiseSeconds = 0.6;

  /// Radians a second while the wheel cruises.
  final double cruiseSpeed;

  /// The wheel angle, clockwise positive.
  double theta;

  /// Radians a second. Negative during the wind back.
  double velocity = 0;
  WheelPhase phase = WheelPhase.idle;

  double _clock = 0;
  double _phaseStart = 0;
  double _phaseTheta = 0;
  WheelLanding? _landing;
  _PendingLanding? _pending;

  /// True from the tap until the wheel is still again.
  bool get busy => phase != WheelPhase.idle && phase != WheelPhase.landed;

  /// True while the wheel turns and no reply has set it down.
  bool get awaitingReply =>
      _pending == null && (phase == WheelPhase.windUp || phase == WheelPhase.spinUp || phase == WheelPhase.cruise);

  /// Where the wheel will stop, once [land] is called and the landing began.
  double? get landingTheta => _landing?.endTheta;

  /// Starts a spin at [now] seconds.
  void start(double now) {
    _clock = now;
    _pending = null;
    _landing = null;
    _enter(WheelPhase.windUp, now, theta);
    velocity = 0;
  }

  /// The reply named a winner: ease out onto slice [index] of [count], [offset] of the way through it. If the wheel is
  /// not yet cruising for [minCruiseSeconds], the landing waits for that.
  void land({required int index, required int count, required double offset}) {
    if (!busy) {
      jumpTo(angleForSlice(index, count, offset));
      return;
    }
    _pending = _PendingLanding(index: index, count: count, offset: offset, repliedAt: _clock);
    if (phase == WheelPhase.cruise) _tryLand(_clock);
  }

  /// No winner: ease to a stop within about 600 ms.
  void stop() {
    if (!busy) return;
    _pending = null;
    _landing = WheelLanding.stop(startTheta: theta, velocity: velocity);
    _enter(WheelPhase.stopping, _clock, theta);
  }

  /// Sets the wheel down at [angle] with no motion (reduced motion).
  void jumpTo(double angle) {
    theta = angle;
    velocity = 0;
    _pending = null;
    _landing = null;
    phase = WheelPhase.landed;
  }

  /// Advances the wheel to [now] seconds.
  void tick(double now) {
    _clock = math.max(now, _clock);
    final double t = _clock;
    while (true) {
      switch (phase) {
        case WheelPhase.idle:
        case WheelPhase.landed:
          velocity = 0;
          return;
        case WheelPhase.windUp:
          final double u = (t - _phaseStart) / windUpSeconds;
          if (u < 1) {
            theta = _phaseTheta - windUpAngle * math.sin(u * math.pi / 2);
            velocity = -windUpAngle * math.cos(u * math.pi / 2) * (math.pi / 2) / windUpSeconds;
            return;
          }
          _enter(WheelPhase.spinUp, _phaseStart + windUpSeconds, _phaseTheta - windUpAngle);
        case WheelPhase.spinUp:
          final double u = (t - _phaseStart) / spinUpSeconds;
          if (u < 1) {
            theta = _phaseTheta + cruiseSpeed * spinUpSeconds * (u * u * u - u * u * u * u / 2);
            velocity = cruiseSpeed * (3 * u * u - 2 * u * u * u);
            return;
          }
          _enter(WheelPhase.cruise, _phaseStart + spinUpSeconds, _phaseTheta + cruiseSpeed * spinUpSeconds / 2);
        case WheelPhase.cruise:
          if (_tryLand(t)) continue;
          theta = _phaseTheta + cruiseSpeed * (t - _phaseStart);
          velocity = cruiseSpeed;
          return;
        case WheelPhase.landing:
        case WheelPhase.stopping:
          final WheelLanding landing = _landing!;
          final double elapsed = t - _phaseStart;
          theta = landing.thetaAt(elapsed);
          velocity = landing.velocityAt(elapsed);
          if (elapsed >= landing.duration) {
            theta = landing.endTheta;
            velocity = 0;
            phase = phase == WheelPhase.landing ? WheelPhase.landed : WheelPhase.idle;
          }
          return;
      }
    }
  }

  /// Begins the pending landing when the cruise has lasted [minCruiseSeconds]. The landing starts at the exact moment
  /// both the reply and the minimum cruise allow, not at the frame time, so the result does not depend on frame pacing.
  bool _tryLand(double t) {
    final _PendingLanding? pending = _pending;
    if (pending == null) return false;
    final double earliest = _phaseStart + minCruiseSeconds;
    if (t < earliest) return false;
    final double at = math.max(pending.repliedAt, earliest);
    final double startTheta = _phaseTheta + cruiseSpeed * (at - _phaseStart);
    _landing = WheelLanding.on(
      startTheta: startTheta,
      velocity: cruiseSpeed,
      targetIndex: pending.index,
      count: pending.count,
      offsetFraction: pending.offset,
    );
    _pending = null;
    _enter(WheelPhase.landing, at, startTheta);
    return true;
  }

  void _enter(WheelPhase next, double at, double fromTheta) {
    phase = next;
    _phaseStart = at;
    _phaseTheta = fromTheta;
  }
}

class _PendingLanding {
  const _PendingLanding({required this.index, required this.count, required this.offset, required this.repliedAt});

  final int index;
  final int count;
  final double offset;
  final double repliedAt;
}
