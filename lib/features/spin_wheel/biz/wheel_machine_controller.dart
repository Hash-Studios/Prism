import 'package:Prism/features/spin_wheel/domain/bulb_pattern.dart';
import 'package:Prism/features/spin_wheel/domain/pointer_flapper.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_motion.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_spinner.dart';
import 'package:flutter/foundation.dart';

/// Runs the machine off one ticker: the wheel angle, the pointer's flapper and the bulbs. The page owns the ticker and
/// calls [tick] with its elapsed time; the controller owns no widget, so a test can drive it with plain durations.
class WheelMachineController {
  WheelMachineController({required this.segmentCount, this.onPegPass, this.onLanded, this.onStopped})
    : spinner = WheelSpinner(theta: restAngle(segmentCount)) {
    theta = ValueNotifier<double>(spinner.theta);
  }

  /// How fast the bulb comet runs next to the wheel: bulbs a second per radian a second.
  static const double chaseFactor = 0.9;

  /// The shortest time between two peg haptics.
  static const double hapticGap = 0.05;

  final WheelSpinner spinner;
  final PointerFlapper flapper = PointerFlapper();

  /// Slices on the wheel now.
  int segmentCount;

  /// A peg passed the pointer. Called at most once every [hapticGap] seconds, so it is safe to play a haptic here.
  final VoidCallback? onPegPass;

  /// The wheel stopped on the winning slice.
  final VoidCallback? onLanded;

  /// The wheel stopped after a refusal or a failure.
  final VoidCallback? onStopped;

  late final ValueNotifier<double> theta;
  final ValueNotifier<double> flapperAngle = ValueNotifier<double>(0);
  final ValueNotifier<BulbFrame> bulbs = ValueNotifier<BulbFrame>(const BulbFrame());

  double _now = 0;
  double _lastElapsed = 0;
  double _chase = 0;
  double? _landedAt;
  double _lastPegPass = -1;
  bool _reduceMotion = false;

  /// True from the tap until the wheel is still.
  bool get busy => spinner.busy;

  /// True once the wheel is in motion and no reply has told it where to stop.
  bool get awaitingReply => spinner.awaitingReply;

  /// Reduced motion: the wheel jumps to its target and the bulbs hold still.
  void setReduceMotion({required bool reduce}) {
    _reduceMotion = reduce;
    if (reduce) _publish();
  }

  /// Begins a spin: wind back, speed up, cruise.
  void start() {
    _landedAt = null;
    spinner.start(_now);
  }

  /// The reply named slice [index]. Ease out onto it, [offset] of the way through the slice. Under reduced motion, or
  /// when the wheel never started (reduced motion was turned off mid-spin), it jumps there and [onLanded] fires at once.
  void land({required int index, required int count, required double offset}) {
    segmentCount = count;
    if (_reduceMotion || !spinner.busy) {
      spinner.jumpTo(angleForSlice(index, count));
      _landedAt = _now - bulbFlashSeconds;
      _publish();
      onLanded?.call();
      return;
    }
    spinner.land(index: index, count: count, offset: offset);
  }

  /// The reply named no winner. Ease to a stop.
  void stop() {
    if (_reduceMotion || !spinner.busy) {
      spinner.stop();
      _publish();
      onStopped?.call();
      return;
    }
    spinner.stop();
  }

  void tick(Duration elapsed) {
    final double seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    // A ticker that was stopped and started again counts from 0. The controller's clock only moves forward.
    final double delta = seconds > _lastElapsed ? seconds - _lastElapsed : 0;
    _lastElapsed = seconds;
    _now += delta;
    final double now = _now;
    final double dt = delta.clamp(0.0, 0.1);
    if (_reduceMotion) {
      _publish();
      return;
    }
    final WheelPhase before = spinner.phase;
    final double from = spinner.theta;
    spinner.tick(now);
    final int passes = flapper.update(dt, from, spinner.theta, segmentCount);
    if (passes > 0 && now - _lastPegPass >= hapticGap) {
      _lastPegPass = now;
      onPegPass?.call();
    }
    _chase += spinner.velocity.abs() * dt * chaseFactor;
    final WheelPhase after = spinner.phase;
    if (before != WheelPhase.landed && after == WheelPhase.landed) {
      _landedAt = now;
      _publish();
      onLanded?.call();
      return;
    }
    if (before == WheelPhase.stopping && after == WheelPhase.idle) {
      _publish();
      onStopped?.call();
      return;
    }
    _publish();
  }

  void _publish() {
    theta.value = spinner.theta;
    flapperAngle.value = _reduceMotion ? 0 : flapper.angle;
    final double? landedAt = _landedAt;
    final bool flashing = landedAt != null;
    bulbs.value = _reduceMotion
        ? BulbFrame(mode: flashing ? BulbMode.landed : BulbMode.idle, flash: bulbFlashSeconds)
        : BulbFrame(
            mode: spinner.busy
                ? BulbMode.spinning
                : flashing && _now - landedAt < bulbFlashSeconds
                ? BulbMode.landed
                : BulbMode.idle,
            time: _now,
            chase: _chase,
            flash: flashing ? _now - landedAt : 0,
          );
  }

  void dispose() {
    theta.dispose();
    flapperAngle.dispose();
    bulbs.dispose();
  }
}
