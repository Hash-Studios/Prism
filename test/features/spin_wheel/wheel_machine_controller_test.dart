import 'package:Prism/features/spin_wheel/biz/wheel_machine_controller.dart';
import 'package:Prism/features/spin_wheel/domain/bulb_pattern.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_motion.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_spinner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int pegs;
  late int landed;
  late int stopped;
  late WheelMachineController controller;

  setUp(() {
    pegs = 0;
    landed = 0;
    stopped = 0;
    controller = WheelMachineController(
      segmentCount: 8,
      onPegPass: () => pegs++,
      onLanded: () => landed++,
      onStopped: () => stopped++,
    );
    addTearDown(controller.dispose);
  });

  /// Runs 60 fps frames from [from] to [to] milliseconds.
  void run(int from, int to) {
    for (int ms = from; ms <= to; ms += 16) {
      controller.tick(Duration(milliseconds: ms));
    }
  }

  test('starts at rest with slice 0 centred under the pointer and the bulbs twinkling', () {
    expect(controller.theta.value, restAngle(8));
    expect(sliceUnderPointer(controller.theta.value, 8), 0);
    controller.tick(Duration.zero);
    expect(controller.bulbs.value.mode, BulbMode.idle);
    expect(controller.busy, isFalse);
  });

  test('a spin turns the wheel, chases the bulbs and plays a throttled haptic for the pegs', () {
    run(0, 100);
    expect(pegs, 0, reason: 'An idle wheel passes no pegs');
    controller.start();
    run(116, 2100);

    expect(controller.busy, isTrue);
    expect(controller.bulbs.value.mode, BulbMode.spinning);
    expect(controller.bulbs.value.chase, greaterThan(10));
    expect(controller.flapperAngle.value, isNot(0));
    // About 2 s at 2.6 turns a second passes 40 pegs. At most one haptic per 50 ms is 40 in 2 s, and every other
    // 16 ms frame is skipped by the throttle, so there are fewer but plenty.
    expect(pegs, inInclusiveRange(10, 40));
  });

  test('lands on the named slice, fires onLanded once and flashes the bulbs three times', () {
    controller.start();
    run(0, 700);
    controller.land(index: 5, count: 8, offset: 0.5);
    run(716, 8000);

    expect(landed, 1);
    expect(stopped, 0);
    expect(controller.busy, isFalse);
    expect(sliceUnderPointer(controller.theta.value, 8), 5);
    expect(controller.flapperAngle.value.abs(), lessThan(0.001));
    expect(controller.bulbs.value.mode, BulbMode.idle);
  });

  test('the bulbs flash right after the landing', () {
    controller.start();
    run(0, 700);
    controller.land(index: 2, count: 8, offset: 0.4);
    BulbMode? seen;
    for (int ms = 716; ms < 9000 && landed == 0; ms += 16) {
      controller.tick(Duration(milliseconds: ms));
    }
    expect(landed, 1);
    seen = controller.bulbs.value.mode;
    expect(seen, BulbMode.landed);
    expect(controller.bulbs.value.flash, closeTo(0, 0.05));
  });

  test('a refusal eases to a stop and fires onStopped, not onLanded', () {
    controller.start();
    run(0, 1500);
    controller.stop();
    run(1516, 2500);

    expect(stopped, 1);
    expect(landed, 0);
    expect(controller.busy, isFalse);
    expect(controller.spinner.phase, WheelPhase.idle);
  });

  test('reduced motion jumps to the target at once', () {
    controller.setReduceMotion(reduce: true);
    controller.start();
    controller.land(index: 6, count: 8, offset: 0.5);

    expect(landed, 1);
    expect(sliceUnderPointer(controller.theta.value, 8), 6);
    expect(controller.bulbs.value.mode, BulbMode.landed);
    expect(controller.bulbs.value.flash, bulbFlashSeconds);
    expect(controller.flapperAngle.value, 0);
  });

  test('reduced motion stops at once too', () {
    controller.setReduceMotion(reduce: true);
    controller.stop();
    expect(stopped, 1);
  });

  test('the table can change size when the reply lands: the wheel lands on the new table', () {
    controller.start();
    run(0, 700);
    controller.land(index: 2, count: 5, offset: 0.6);
    run(716, 8000);
    expect(landed, 1);
    expect(controller.segmentCount, 5);
    expect(sliceUnderPointer(controller.theta.value, 5), 2);
  });

  test('a ticker that restarts from zero does not run the clock backwards', () {
    run(0, 500);
    controller.start();
    run(516, 1000);
    final double before = controller.theta.value;
    controller.tick(const Duration(milliseconds: 20));
    expect(controller.theta.value, closeTo(before, 1e-9));
    controller.tick(const Duration(milliseconds: 36));
    expect(controller.theta.value, greaterThan(before));
  });
}
