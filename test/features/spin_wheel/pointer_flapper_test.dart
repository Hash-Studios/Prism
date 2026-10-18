import 'package:Prism/features/spin_wheel/domain/bulb_pattern.dart';
import 'package:Prism/features/spin_wheel/domain/pointer_flapper.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const int n = 8;
  final double s = sliceWidth(n);

  test('a peg passing the pointer is counted once and swings the tip along the spin', () {
    final PointerFlapper flapper = PointerFlapper();
    int passes = 0;
    double peak = 0;
    // 1 rad/s from before the peg at theta 0 to after it.
    double theta = -0.3;
    while (theta < 0.3) {
      passes += flapper.update(0.004, theta, theta + 0.004, n);
      peak = flapper.angle > peak ? flapper.angle : peak;
      theta += 0.004;
    }
    expect(passes, 1);
    expect(peak, closeTo(PointerFlapper.maxAngle, 0.01));
  });

  test('a slow peg holds the tip part way and the tip snaps back after the peg slips past', () {
    final PointerFlapper flapper = PointerFlapper();
    // The peg is 0.035 rad before the axis: half way through the contact window of 0.14 rad.
    flapper.update(0.016, -0.04, -0.035, n);
    expect(flapper.angle, closeTo(PointerFlapper.maxAngle * (0.035 / 0.14), 1e-9));
    flapper.update(0.016, 0.06, 0.08, n);
    double now = flapper.angle;
    expect(now, greaterThan(0));
    for (int i = 0; i < 60; i++) {
      flapper.update(0.016, 0.08, 0.08, n);
      now = flapper.angle;
    }
    expect(now.abs(), lessThan(0.001));
  });

  test('a fast wheel pushes the tip fully even when a peg crosses the window inside one frame', () {
    final PointerFlapper flapper = PointerFlapper();
    const double step = 2.6 * wheelTurn / 60;
    final int passes = flapper.update(1 / 60, -step * 0.5, step * 0.5, n);
    expect(passes, 1);
    expect(flapper.angle, greaterThan(PointerFlapper.maxAngle * 0.4));
  });

  test('every peg of a spinning wheel is counted: 8 pegs a turn', () {
    final PointerFlapper flapper = PointerFlapper();
    int passes = 0;
    double theta = restAngle(n);
    const double step = 2.6 * wheelTurn / 60;
    for (int i = 0; i < 60; i++) {
      passes += flapper.update(1 / 60, theta, theta + step, n);
      theta += step;
    }
    // One second at 2.6 turns a second is 20.8 pegs: 20 or 21 pass.
    expect(passes, inInclusiveRange(20, 21));
  });

  test('a wheel that turns back does not count pegs and does not push the tip', () {
    final PointerFlapper flapper = PointerFlapper();
    final int passes = flapper.update(0.1, 0.3, -0.3, n);
    expect(passes, 0);
    expect(flapper.angle, 0);
  });

  test('the tip never swings further than its limit', () {
    final PointerFlapper flapper = PointerFlapper();
    double theta = 0;
    for (int i = 0; i < 600; i++) {
      flapper.update(1 / 60, theta, theta + s / 2.2, n);
      theta += s / 2.2;
      expect(flapper.angle.abs(), lessThanOrEqualTo(PointerFlapper.maxAngle));
    }
  });

  group('bulbIntensity', () {
    double bulb(BulbMode mode, int i, {double time = 0, double chase = 0, double flash = 0}) =>
        bulbIntensity(mode: mode, index: i, time: time, chase: chase, flash: flash);

    test('idle: even and odd bulbs twinkle in opposite phase over 2.8 seconds', () {
      expect(bulb(BulbMode.idle, 0), closeTo(1, 1e-9));
      expect(bulb(BulbMode.idle, 1), closeTo(0.1, 1e-9));
      expect(bulb(BulbMode.idle, 0, time: 1.4), closeTo(0.1, 1e-9));
      expect(bulb(BulbMode.idle, 1, time: 1.4), closeTo(1, 1e-9));
      expect(bulb(BulbMode.idle, 0, time: 2.8), closeTo(1, 1e-9));
    });

    test('spinning: a comet head is full, its tail fades and the bulb ahead is dim', () {
      expect(bulb(BulbMode.spinning, 5, chase: 5), closeTo(1, 1e-9));
      expect(bulb(BulbMode.spinning, 4, chase: 5), closeTo(0.5686, 0.001));
      expect(bulb(BulbMode.spinning, 4, chase: 5), lessThan(bulb(BulbMode.spinning, 5, chase: 5)));
      expect(bulb(BulbMode.spinning, 6, chase: 5), lessThan(0.15));
      expect(bulb(BulbMode.spinning, 6, chase: 6), closeTo(1, 1e-9));
    });

    test('landed: three flashes in 1.2 seconds, then a steady glow', () {
      for (int flash = 0; flash < 3; flash++) {
        final double start = flash * bulbFlashCycle;
        expect(bulb(BulbMode.landed, 3, flash: start), closeTo(0.1, 1e-9));
        expect(bulb(BulbMode.landed, 3, flash: start + bulbFlashCycle / 2), closeTo(1, 1e-9));
      }
      expect(bulb(BulbMode.landed, 3, flash: bulbFlashSeconds), 0.85);
      expect(bulbFlashSeconds, closeTo(1.2, 1e-9));
    });
  });
}
