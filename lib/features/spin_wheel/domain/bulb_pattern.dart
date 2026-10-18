import 'dart:math' as math;

/// What the bulbs on the bezel and the lights on the plinth are doing.
enum BulbMode {
  /// Alternate bulbs twinkle slowly.
  idle,

  /// A comet of light runs round, as fast as the wheel.
  spinning,

  /// Every bulb flashes three times.
  landed,
}

/// Seconds one flash cycle lasts after a landing. Three flashes.
const double bulbFlashCycle = 0.4;
const int bulbFlashCount = 3;

/// How long the landing flashes last.
const double bulbFlashSeconds = bulbFlashCycle * bulbFlashCount;

/// Brightness of bulb [index] from 0 (dim) to 1 (full).
///
/// [time] is the clock in seconds, [chase] the position of the comet in bulbs, [flash] the seconds since the landing.
/// [period] is how many bulbs one comet spans.
double bulbIntensity({
  required BulbMode mode,
  required int index,
  required double time,
  required double chase,
  required double flash,
  int period = 4,
}) {
  switch (mode) {
    case BulbMode.idle:
      final double phase = time / 2.8 + (index.isEven ? 0 : 0.5);
      final double wave = 0.5 + 0.5 * math.cos(phase * 2 * math.pi);
      return 0.1 + 0.9 * _smooth(wave);
    case BulbMode.spinning:
      final double behind = (chase - index) % period;
      return 0.08 + 0.92 * math.pow(1 - behind / period, 2.2);
    case BulbMode.landed:
      if (flash >= bulbFlashSeconds) return 0.85;
      final double within = (flash % bulbFlashCycle) / bulbFlashCycle;
      return 0.1 + 0.9 * _smooth(1 - (within * 2 - 1).abs());
  }
}

double _smooth(double x) => x * x * (3 - 2 * x);
