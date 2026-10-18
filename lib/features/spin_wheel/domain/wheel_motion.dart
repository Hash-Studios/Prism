import 'dart:math' as math;

/// One full turn in radians.
const double wheelTurn = 2 * math.pi;

/// How long the final ease-out lasts before the extra distance to the target. The curve is a quartic ease-out, so the
/// last third of it is a slow crawl.
const double wheelLandingSeconds = 3.4;

/// The shortest landing distance, in full turns. A slow wheel still turns twice before it stops.
const double wheelMinLandingTurns = 2;

/// Width of one slice in radians.
double sliceWidth(int count) => wheelTurn / count;

/// [angle] folded into `[0, 2 * pi)`.
double normalizeAngle(double angle) {
  final double folded = angle % wheelTurn;
  return folded >= wheelTurn ? 0 : folded;
}

/// The slice under the pointer when the wheel is turned [theta] radians clockwise.
///
/// Slice `i` spans `[i * s, (i + 1) * s)` with `s = 2 * pi / count`, measured clockwise from the pointer when the wheel
/// is at angle 0. Turning the wheel clockwise moves a slice away from the pointer, so the point under the pointer is
/// the one at `-theta`.
int sliceUnderPointer(double theta, int count) {
  final int index = (normalizeAngle(-theta) / sliceWidth(count)).floor();
  return math.min(count - 1, index);
}

/// The wheel angle, modulo a turn, that puts the point [fraction] of the way through slice [index] under the pointer.
double angleForSlice(int index, int count, [double fraction = 0.5]) => -(index + fraction) * sliceWidth(count);

/// The idle pose: slice 0 centred under the pointer, so the pointer never rests on a peg.
double restAngle(int count) => angleForSlice(0, count);

/// The angle the wheel stops at when it lands on slice [targetIndex], [offsetFraction] of the way through it.
///
/// It is at least [wheelMinLandingTurns] full turns ahead of [currentTheta]. The base distance is what a quartic
/// ease-out that starts at [velocity] (radians a second) covers in [wheelLandingSeconds]: `velocity * T / 4`. The extra
/// distance, less than one turn, brings the target under the pointer.
double landingAngle(double currentTheta, double velocity, int targetIndex, int count, double offsetFraction) {
  final double base = math.max(velocity * wheelLandingSeconds / 4, wheelMinLandingTurns * wheelTurn);
  final double target = angleForSlice(targetIndex, count, offsetFraction);
  final double extra = normalizeAngle(target - (currentTheta + base));
  return currentTheta + base + extra;
}

/// A quartic ease-out from [startTheta] to [endTheta]: `s(t) = D * (1 - (1 - t / T) ^ 4)` with `T = 4 * D / velocity`.
///
/// The slope at `t = 0` is exactly [velocity], so the wheel leaves its cruise speed without a jump.
class WheelLanding {
  const WheelLanding({required this.startTheta, required this.endTheta, required this.velocity})
    : assert(endTheta > startTheta, 'A landing moves clockwise'),
      assert(velocity > 0, 'A landing starts at speed');

  /// The wheel's landing on slice [targetIndex].
  factory WheelLanding.on({
    required double startTheta,
    required double velocity,
    required int targetIndex,
    required int count,
    required double offsetFraction,
  }) => WheelLanding(
    startTheta: startTheta,
    endTheta: landingAngle(startTheta, velocity, targetIndex, count, offsetFraction),
    velocity: velocity,
  );

  /// A stop that takes [seconds], from wherever the wheel is. A wheel that is nearly still gets a small push so the
  /// stop still reads as an ease.
  factory WheelLanding.stop({required double startTheta, required double velocity, double seconds = 0.6}) {
    final double speed = math.max(velocity, 4);
    return WheelLanding(startTheta: startTheta, endTheta: startTheta + speed * seconds / 4, velocity: speed);
  }

  final double startTheta;
  final double endTheta;

  /// Radians a second at `t = 0`.
  final double velocity;

  double get distance => endTheta - startTheta;

  /// Seconds from the first frame to rest.
  double get duration => 4 * distance / velocity;

  double thetaAt(double seconds) {
    if (seconds >= duration) return endTheta;
    if (seconds <= 0) return startTheta;
    return startTheta + distance * (1 - math.pow(1 - seconds / duration, 4));
  }

  double velocityAt(double seconds) {
    if (seconds >= duration) return 0;
    if (seconds <= 0) return velocity;
    return velocity * math.pow(1 - seconds / duration, 3);
  }
}
