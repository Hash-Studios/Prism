import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart' as motor;

/// Built-in transition presets for [BottomBar].
///
/// Pair with [BottomBarMotion.transition]. To customize beyond the presets,
/// supply [BottomBarMotion.transitionBuilder] (which overrides this enum).
enum BottomBarTransition {
  /// Slide the bar from offscreen toward its rest position.
  slide,

  /// Fade the bar in and out without translation.
  fade,

  /// Scale the bar from 0.0 to 1.0 (and back) while showing/hiding.
  scale,

  /// Slide and fade simultaneously.
  slideAndFade,
}

/// Animation engine used by [BottomBarMotion].
enum BottomBarMotionMode {
  /// Apple-style spring presets backed by Motor's [motor.CupertinoMotion].
  cupertino,

  /// Traditional duration + curve motion.
  curved,

  /// A caller-supplied Motor motion.
  motor,
}

/// Built-in Cupertino spring presets for [BottomBarMotion.cupertino].
///
/// Each preset maps to the corresponding [motor.CupertinoMotion] factory.
enum BottomBarCupertinoMotion {
  /// A gentle, slower spring — good for large panels or decorative transitions.
  smooth,

  /// A crisp, fast spring. The default preset; works well for tab bars.
  snappy,

  /// A spring with noticeable overshoot, similar to iOS app icon launches.
  bouncy,

  /// A highly responsive spring tuned for drag-following interactions.
  interactive,
}

/// Animation configuration for [BottomBar] show/hide.
///
/// Three named constructors cover the common cases:
///
/// ```dart
/// // Default: Motor-backed Cupertino spring (snappy preset).
/// const BottomBarMotion()
///
/// // Explicit spring preset.
/// const BottomBarMotion.cupertino(preset: BottomBarCupertinoMotion.bouncy)
///
/// // Traditional duration + curve animation.
/// const BottomBarMotion.curved(
///   duration: Duration(milliseconds: 280),
///   curve: Curves.easeOutCubic,
/// )
///
/// // Any Motor motion.
/// const BottomBarMotion.motor(Motion.snappySpring())
/// ```
///
/// When using a [transitionBuilder] with a spring-based motion, clamp
/// `animation.value` to `[0, 1]` before using it for opacity or scale — springs
/// can overshoot:
///
/// ```dart
/// transitionBuilder: (context, animation, child) {
///   final v = animation.value.clamp(0.0, 1.0);
///   return Opacity(opacity: v, child: child);
/// },
/// ```
///
/// Custom transitions must preserve the child's layout footprint. Use
/// paint-only wrappers such as [Opacity], [Transform], or other effects that
/// do not change layout size. Layout-affecting wrappers such as
/// [SizeTransition], [Align] with `heightFactor`, or similar size-changing
/// widgets are unsupported because [BottomBarScope.barHeight] and
/// [BottomBarBodyPadding] guarantee stable reserved footprint while the bar
/// animates in and out.
///
/// If the platform requests reduced motion, [BottomBar] snaps directly to the
/// shown/hidden target state instead of animating through this motion.
@immutable
class BottomBarMotion {
  static const Duration _defaultCupertinoDuration = Duration(milliseconds: 500);
  static const Duration _defaultCurvedDuration = Duration(milliseconds: 240);
  static const Curve _defaultCurve = Curves.easeOutCubic;

  /// Creates a [BottomBarMotion] with sensible defaults.
  ///
  /// When neither [duration] nor [curve] is supplied the bar uses a
  /// Motor-backed Cupertino spring ([BottomBarCupertinoMotion.snappy]) for a
  /// native-feeling hide/show. Pass either parameter to switch to
  /// [BottomBarMotionMode.curved] mode.
  const BottomBarMotion({
    Duration? duration,
    Curve? curve,
    this.transition = BottomBarTransition.slide,
    this.transitionBuilder,
    this.slideStart = const Offset(0, 2),
    this.slideEnd = Offset.zero,
  }) : mode = duration == null && curve == null
           ? BottomBarMotionMode.cupertino
           : BottomBarMotionMode.curved,
       duration =
           duration ??
           (curve == null ? _defaultCupertinoDuration : _defaultCurvedDuration),
       curve = curve ?? _defaultCurve,
       cupertinoPreset = BottomBarCupertinoMotion.snappy,
       extraBounce = 0,
       snapToEnd = true,
       motorMotion = null;

  /// Creates a Cupertino spring motion using one of the built-in presets.
  ///
  /// The spring redirects velocity when scroll direction reverses mid-animation,
  /// matching iOS native bottom bar behaviour.
  ///
  /// [preset] defaults to [BottomBarCupertinoMotion.snappy].
  /// Increase [extraBounce] (e.g. `0.04`) for more dramatic overshoot.
  const BottomBarMotion.cupertino({
    BottomBarCupertinoMotion preset = BottomBarCupertinoMotion.snappy,
    this.duration = _defaultCupertinoDuration,
    this.extraBounce = 0,
    this.snapToEnd = true,
    this.transition = BottomBarTransition.slide,
    this.transitionBuilder,
    this.slideStart = const Offset(0, 2),
    this.slideEnd = Offset.zero,
  }) : mode = BottomBarMotionMode.cupertino,
       curve = _defaultCurve,
       cupertinoPreset = preset,
       motorMotion = null;

  /// Creates a deterministic duration + curve animation.
  ///
  /// Use this when you need a predictable, fixed-duration transition — e.g. to
  /// match an existing animation in your app. For a more iOS-native feel prefer
  /// [BottomBarMotion.cupertino].
  const BottomBarMotion.curved({
    this.duration = _defaultCurvedDuration,
    this.curve = _defaultCurve,
    this.transition = BottomBarTransition.slide,
    this.transitionBuilder,
    this.slideStart = const Offset(0, 2),
    this.slideEnd = Offset.zero,
  }) : mode = BottomBarMotionMode.curved,
       cupertinoPreset = BottomBarCupertinoMotion.snappy,
       extraBounce = 0,
       snapToEnd = true,
       motorMotion = null;

  /// Creates a motion driven by a caller-supplied [motor.Motion].
  ///
  /// Use this to pass any Motion from the `motor` package directly —
  /// e.g. `Motion.snappySpring()` or a fully customised spring. `Motion` is
  /// intentionally re-exported by this package. The
  /// [duration] and [curve] parameters are only used for the
  /// scroll-to-boundary animation, not for show/hide.
  const BottomBarMotion.motor(
    this.motorMotion, {
    this.duration = _defaultCurvedDuration,
    this.curve = _defaultCurve,
    this.transition = BottomBarTransition.slide,
    this.transitionBuilder,
    this.slideStart = const Offset(0, 2),
    this.slideEnd = Offset.zero,
  }) : mode = BottomBarMotionMode.motor,
       cupertinoPreset = BottomBarCupertinoMotion.snappy,
       extraBounce = 0,
       snapToEnd = true;

  /// Which motion engine drives the bar.
  final BottomBarMotionMode mode;

  /// Duration used by curve motion and as the estimated duration for springs.
  final Duration duration;

  /// Curve used by [BottomBarMotionMode.curved] and scroll-to-boundary actions.
  final Curve curve;

  /// Cupertino spring preset used by [BottomBarMotionMode.cupertino].
  final BottomBarCupertinoMotion cupertinoPreset;

  /// Additional bounce applied to Cupertino presets.
  final double extraBounce;

  /// Whether Motor should snap exactly to the target when the spring settles.
  final bool snapToEnd;

  /// Custom Motor motion used when [mode] is [BottomBarMotionMode.motor].
  final motor.Motion? motorMotion;

  /// Built-in preset to use when [transitionBuilder] is null.
  final BottomBarTransition transition;

  /// When non-null, takes precedence over [transition]; receives the bar's
  /// `Animation<double>` (from 0 hidden → 1 shown) and the bar child.
  ///
  /// The returned widget must preserve the child's layout footprint. Restrict
  /// custom transitions to paint-only effects such as [Opacity],
  /// [Transform.translate], or [Transform.scale]. Layout-affecting wrappers
  /// such as [SizeTransition] or [Align] with a non-null `heightFactor` are
  /// unsupported because they break the stable footprint contract used by
  /// [BottomBarScope.barHeight] and [BottomBarBodyPadding]. Spring-driven
  /// animations may overshoot, so clamp `animation.value` before using it for
  /// opacity or scale.
  final Widget Function(BuildContext, Animation<double>, Widget)?
  transitionBuilder;

  /// Slide source offset (used by `BottomBarTransition.slide` and
  /// `BottomBarTransition.slideAndFade`), in multiples of the bar's size.
  ///
  /// For `slide`, it is measured from where the bar sits flush against the
  /// edge of the [BottomBar] it slides toward, so `Offset(0, 1)` hides the
  /// bar exactly and the default `Offset(0, 2)` leaves one bar height of
  /// clearance (room for shadows or children painted outside the bar),
  /// whatever the layout offset, safe-area padding or keyboard lift.
  /// For `slideAndFade` it is measured from the bar's resting position, as
  /// in `SlideTransition.position`, since the fade already hides the bar.
  final Offset slideStart;

  /// Slide rest offset (the visible position).
  final Offset slideEnd;

  /// Returns a copy of this motion with the given fields replaced by
  /// non-null values. Null arguments leave the corresponding field unchanged.
  ///
  /// The [mode] of the returned object matches the [mode] argument (or the
  /// current mode if null), so the correct named constructor is used internally.
  BottomBarMotion copyWith({
    BottomBarMotionMode? mode,
    Duration? duration,
    Curve? curve,
    BottomBarCupertinoMotion? cupertinoPreset,
    double? extraBounce,
    bool? snapToEnd,
    motor.Motion? motorMotion,
    BottomBarTransition? transition,
    Widget Function(BuildContext, Animation<double>, Widget)? transitionBuilder,
    Offset? slideStart,
    Offset? slideEnd,
  }) {
    duration ??= this.duration;
    curve ??= this.curve;
    transition ??= this.transition;
    transitionBuilder ??= this.transitionBuilder;
    slideStart ??= this.slideStart;
    slideEnd ??= this.slideEnd;
    return switch (mode ?? this.mode) {
      BottomBarMotionMode.cupertino => BottomBarMotion.cupertino(
        preset: cupertinoPreset ?? this.cupertinoPreset,
        duration: duration,
        extraBounce: extraBounce ?? this.extraBounce,
        snapToEnd: snapToEnd ?? this.snapToEnd,
        transition: transition,
        transitionBuilder: transitionBuilder,
        slideStart: slideStart,
        slideEnd: slideEnd,
      ),
      BottomBarMotionMode.curved => BottomBarMotion.curved(
        duration: duration,
        curve: curve,
        transition: transition,
        transitionBuilder: transitionBuilder,
        slideStart: slideStart,
        slideEnd: slideEnd,
      ),
      BottomBarMotionMode.motor => BottomBarMotion.motor(
        motorMotion ?? this.motorMotion ?? motor.Motion.curved(duration, curve),
        duration: duration,
        curve: curve,
        transition: transition,
        transitionBuilder: transitionBuilder,
        slideStart: slideStart,
        slideEnd: slideEnd,
      ),
    };
  }

  /// Resolves this package-level configuration to the Motor motion that drives
  /// the controller.
  motor.Motion resolveMotion() {
    switch (mode) {
      case BottomBarMotionMode.cupertino:
        return switch (cupertinoPreset) {
          BottomBarCupertinoMotion.smooth => motor.CupertinoMotion.smooth(
            duration: duration,
            extraBounce: extraBounce,
            snapToEnd: snapToEnd,
          ),
          BottomBarCupertinoMotion.snappy => motor.CupertinoMotion.snappy(
            duration: duration,
            extraBounce: extraBounce,
            snapToEnd: snapToEnd,
          ),
          BottomBarCupertinoMotion.bouncy => motor.CupertinoMotion.bouncy(
            duration: duration,
            extraBounce: extraBounce,
            snapToEnd: snapToEnd,
          ),
          BottomBarCupertinoMotion.interactive =>
            motor.CupertinoMotion.interactive(
              duration: duration,
              extraBounce: extraBounce,
              snapToEnd: snapToEnd,
            ),
        };
      case BottomBarMotionMode.curved:
        return motor.Motion.curved(duration, curve);
      case BottomBarMotionMode.motor:
        return motorMotion ?? motor.Motion.curved(duration, curve);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BottomBarMotion &&
        other.mode == mode &&
        other.duration == duration &&
        other.curve == curve &&
        other.cupertinoPreset == cupertinoPreset &&
        other.extraBounce == extraBounce &&
        other.snapToEnd == snapToEnd &&
        other.motorMotion == motorMotion &&
        other.transition == transition &&
        other.transitionBuilder == transitionBuilder &&
        other.slideStart == slideStart &&
        other.slideEnd == slideEnd;
  }

  @override
  int get hashCode => Object.hash(
    mode,
    duration,
    curve,
    cupertinoPreset,
    extraBounce,
    snapToEnd,
    motorMotion,
    transition,
    transitionBuilder,
    slideStart,
    slideEnd,
  );
}
