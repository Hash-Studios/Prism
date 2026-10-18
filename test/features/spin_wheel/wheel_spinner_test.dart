import 'package:Prism/features/spin_wheel/domain/wheel_motion.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_spinner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const double cruise = WheelSpinner.defaultCruiseSpeed;

  /// Runs the spinner at 60 fps to [until] seconds.
  void run(WheelSpinner spinner, double from, double until) {
    for (double t = from; t <= until + 1e-9; t += 1 / 60) {
      spinner.tick(t);
    }
  }

  test('the cruise speed is 2.6 turns a second', () {
    expect(cruise, closeTo(16.336, 0.001));
  });

  test('a spin winds back 0.12 rad in 160 ms, speeds up in 500 ms and then cruises at full speed', () {
    final WheelSpinner spinner = WheelSpinner(theta: 1);
    spinner.start(0);
    expect(spinner.phase, WheelPhase.windUp);

    spinner.tick(0.16);
    expect(spinner.theta, closeTo(1 - 0.12, 1e-9));
    expect(spinner.velocity, closeTo(0, 1e-6));

    spinner.tick(0.17);
    expect(spinner.phase, WheelPhase.spinUp);
    expect(spinner.velocity, greaterThan(0));

    spinner.tick(0.66);
    expect(spinner.phase, WheelPhase.cruise);
    expect(spinner.velocity, cruise);
    // Wind back, then the spin up covers half of speed times duration.
    expect(spinner.theta, closeTo(1 - 0.12 + cruise * 0.5 * 0.5, 1e-6));

    spinner.tick(1.66);
    expect(spinner.theta, closeTo(1 - 0.12 + cruise * 0.25 + cruise * 1.0, 1e-6));
  });

  test('the speed never jumps between phases', () {
    final WheelSpinner spinner = WheelSpinner();
    spinner.start(0);
    spinner.tick(0);
    double previous = spinner.velocity;
    for (double t = 0.001; t < 1.2; t += 0.001) {
      spinner.tick(t);
      expect((spinner.velocity - previous).abs(), lessThan(0.6), reason: 't=$t');
      previous = spinner.velocity;
    }
  });

  test('a reply that comes at once waits for 600 ms of cruise, then lands on the target', () {
    final WheelSpinner spinner = WheelSpinner(theta: restAngle(8));
    spinner.start(0);
    run(spinner, 0, 0.1);
    spinner.land(index: 3, count: 8, offset: 0.4);
    expect(spinner.awaitingReply, isFalse);

    run(spinner, 0.1, 1.2);
    expect(spinner.phase, WheelPhase.cruise, reason: 'cruise began at 0.66 s, so it lasts until 1.26 s');
    run(spinner, 1.2, 1.4);
    expect(spinner.phase, WheelPhase.landing);
    expect(spinner.landingTheta, isNotNull);

    run(spinner, 1.4, 1.26 + 5.9);
    expect(spinner.phase, WheelPhase.landed);
    expect(spinner.velocity, 0);
    expect(sliceUnderPointer(spinner.theta, 8), 3);
    expect((normalizeAngle(-spinner.theta) / sliceWidth(8)) - 3, closeTo(0.4, 1e-9));
  });

  test('a late reply lands from the moment it arrives, at the cruise speed', () {
    final WheelSpinner spinner = WheelSpinner();
    spinner.start(0);
    run(spinner, 0, 3);
    expect(spinner.phase, WheelPhase.cruise);
    expect(spinner.awaitingReply, isTrue);
    spinner.land(index: 6, count: 8, offset: 0.7);
    expect(spinner.phase, WheelPhase.landing);
    expect(spinner.velocity, cruise);
    run(spinner, 3, 3 + 6);
    expect(spinner.phase, WheelPhase.landed);
    expect(sliceUnderPointer(spinner.theta, 8), 6);
  });

  test('the landing does not depend on the frame rate', () {
    int land(double step) {
      final WheelSpinner spinner = WheelSpinner(theta: restAngle(8));
      spinner.start(0);
      for (double t = 0; t < 0.5; t += step) {
        spinner.tick(t);
      }
      spinner.land(index: 2, count: 8, offset: 0.5);
      for (double t = 0.5; t < 9; t += step) {
        spinner.tick(t);
      }
      return sliceUnderPointer(spinner.theta, 8);
    }

    expect(land(1 / 120), 2);
    expect(land(1 / 30), 2);
    expect(land(0.25), 2);
  });

  test('a refusal eases the wheel to a stop in about 600 ms', () {
    final WheelSpinner spinner = WheelSpinner();
    spinner.start(0);
    run(spinner, 0, 1.5);
    final double before = spinner.theta;
    spinner.stop();
    expect(spinner.phase, WheelPhase.stopping);
    run(spinner, 1.5, 1.5 + 0.65);
    expect(spinner.phase, WheelPhase.idle);
    expect(spinner.velocity, 0);
    expect(spinner.theta - before, closeTo(cruise * 0.6 / 4, 1e-6));
    expect(spinner.busy, isFalse);
  });

  test('a stop that comes during the wind back still ends in rest', () {
    final WheelSpinner spinner = WheelSpinner();
    spinner.start(0);
    run(spinner, 0, 0.05);
    spinner.stop();
    run(spinner, 0.05, 0.8);
    expect(spinner.phase, WheelPhase.idle);
    expect(spinner.velocity, 0);
  });

  test('jumpTo sets the wheel down at once', () {
    final WheelSpinner spinner = WheelSpinner();
    spinner.jumpTo(angleForSlice(4, 8));
    expect(spinner.phase, WheelPhase.landed);
    expect(sliceUnderPointer(spinner.theta, 8), 4);
    spinner.land(index: 1, count: 8, offset: 0.5);
    expect(sliceUnderPointer(spinner.theta, 8), 1);
  });

  test('a new spin starts from where the last one stopped', () {
    final WheelSpinner spinner = WheelSpinner();
    spinner.jumpTo(10);
    spinner.start(5);
    spinner.tick(5.159999);
    expect(spinner.theta, closeTo(10 - 0.12, 1e-6));
    expect(spinner.phase, WheelPhase.windUp);
    spinner.tick(5.2);
    expect(spinner.phase, WheelPhase.spinUp);
    expect(spinner.theta, lessThan(10), reason: 'the wheel is still behind its start');
  });
}
