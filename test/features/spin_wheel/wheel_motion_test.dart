import 'dart:math' as math;

import 'package:Prism/features/spin_wheel/domain/wheel_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const double twoPi = 2 * math.pi;

  group('sliceUnderPointer', () {
    test('slice 0 starts at the pointer and a clockwise turn brings the earlier slices under it', () {
      expect(sliceUnderPointer(0, 8), 0);
      expect(sliceUnderPointer(-0.01, 8), 0);
      // Turning the wheel clockwise moves slice 0 away from the pointer, so slice 7 comes under it.
      expect(sliceUnderPointer(0.01, 8), 7);
      expect(sliceUnderPointer(twoPi / 8 + 0.01, 8), 6);
      expect(sliceUnderPointer(7 * twoPi / 8 + 0.01, 8), 0);
      // Turning it back brings slice 1 under the pointer.
      expect(sliceUnderPointer(-twoPi / 8 - 0.01, 8), 1);
    });

    test('the rest angle centres slice 0 under the pointer', () {
      for (final int n in <int>[2, 5, 8, 12]) {
        expect(restAngle(n), closeTo(-math.pi / n, 1e-12));
        expect(sliceUnderPointer(restAngle(n), n), 0);
      }
    });

    test('whole turns change nothing', () {
      for (final double turns in <double>[-3, -1, 1, 4, 12]) {
        expect(sliceUnderPointer(turns * twoPi - 0.3, 8), sliceUnderPointer(-0.3, 8));
      }
    });
  });

  group('landingAngle', () {
    test('lands on every slice of every wheel at 20, 50 and 80 percent through it', () {
      for (final int n in <int>[2, 5, 8, 12]) {
        for (int target = 0; target < n; target++) {
          for (final double offset in <double>[0.2, 0.5, 0.8]) {
            for (final double start in <double>[-1.7, 0, 0.4, 3.9, 25.3]) {
              for (final double speed in <double>[3, 9.5, 16.34, 22]) {
                final double end = landingAngle(start, speed, target, n, offset);
                expect(
                  sliceUnderPointer(end, n),
                  target,
                  reason: 'n=$n target=$target offset=$offset start=$start speed=$speed',
                );
                // The stop sits at the asked offset inside the slice.
                final double inside = (normalizeAngle(-end) / sliceWidth(n)) - target;
                expect(inside, closeTo(offset, 1e-9));
                expect(end - start, greaterThanOrEqualTo(2 * twoPi));
                expect(end - start, greaterThan(0));
              }
            }
          }
        }
      }
    });

    test('the base distance is the speed times 3.4 s over 4, plus less than a turn', () {
      final double end = landingAngle(0, 16.34, 3, 8, 0.5);
      const double base = 16.34 * 3.4 / 4;
      expect(end, greaterThanOrEqualTo(base));
      expect(end, lessThan(base + twoPi));
    });

    test('a slow wheel still turns at least twice', () {
      final double end = landingAngle(1, 1, 0, 8, 0.5);
      expect(end - 1, greaterThanOrEqualTo(2 * twoPi));
      expect(end - 1, lessThan(3 * twoPi));
    });
  });

  group('WheelLanding', () {
    test('starts at the cruise speed, ends at rest on the target and never goes backwards', () {
      const double speed = 2.6 * twoPi;
      final WheelLanding landing = WheelLanding.on(
        startTheta: 1.25,
        velocity: speed,
        targetIndex: 5,
        count: 8,
        offsetFraction: 0.35,
      );
      expect(landing.velocityAt(0), speed);
      expect((landing.thetaAt(0.001) - landing.thetaAt(0)) / 0.001, closeTo(speed, speed * 0.01));
      expect(landing.thetaAt(0), 1.25);
      expect(landing.thetaAt(landing.duration), landing.endTheta);
      expect(landing.velocityAt(landing.duration), 0);
      expect(landing.duration, closeTo(4 * landing.distance / speed, 1e-12));
      expect(landing.duration, inInclusiveRange(3.4, 3.4 + 4 * twoPi / speed));
      double previous = landing.thetaAt(0);
      for (double t = 0.05; t < landing.duration; t += 0.05) {
        final double now = landing.thetaAt(t);
        expect(now, greaterThanOrEqualTo(previous));
        expect(landing.velocityAt(t), lessThan(speed));
        previous = now;
      }
      expect(sliceUnderPointer(landing.endTheta, 8), 5);
    });

    test('the curve is the quartic ease-out D * (1 - (1 - t / T) ^ 4)', () {
      const WheelLanding landing = WheelLanding(startTheta: 0, endTheta: 20, velocity: 16);
      expect(landing.duration, 5);
      expect(landing.thetaAt(2.5), closeTo(20 * (1 - 0.0625), 1e-12));
      expect(landing.velocityAt(2.5), closeTo(16 * 0.125, 1e-12));
    });

    test('a stop takes 0.6 seconds and starts at the current speed', () {
      final WheelLanding stop = WheelLanding.stop(startTheta: 2, velocity: 16.34);
      expect(stop.duration, closeTo(0.6, 1e-12));
      expect(stop.velocityAt(0), 16.34);
      expect(stop.distance, closeTo(16.34 * 0.6 / 4, 1e-12));
    });

    test('a stop from a nearly still wheel gets a small push', () {
      final WheelLanding stop = WheelLanding.stop(startTheta: 0, velocity: -2);
      expect(stop.velocity, 4);
      expect(stop.duration, closeTo(0.6, 1e-12));
    });
  });
}
