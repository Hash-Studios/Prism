import 'package:Prism/core/motion/prism_motion.dart';
import 'package:flutter/widgets.dart';

/// Fires a [ShakeOnce] for one [target] (for example a grid index).
class ShakeController extends ChangeNotifier {
  Object? _target;

  /// The target of the last [shake] call.
  Object? get target => _target;

  /// Shakes the [ShakeOnce] whose `target` equals [target].
  void shake([Object? target]) {
    _target = target;
    notifyListeners();
  }
}

/// Plays one short "shrink and settle" pulse on [child] when [controller] shakes its [target].
/// Skipped under reduce motion.
class ShakeOnce extends StatefulWidget {
  const ShakeOnce({super.key, required this.controller, this.child, this.target, this.distance = 8, this.builder});

  final ShakeController controller;
  final Widget? child;

  /// This widget only plays when the controller shakes this value.
  final Object? target;

  /// Peak inset in logical pixels.
  final double distance;

  /// Replaces the default inset. [value] runs from 0 to [distance] and back to 0.
  final Widget Function(BuildContext context, double value, Widget? child)? builder;

  @override
  State<ShakeOnce> createState() => _ShakeOnceState();
}

class _ShakeOnceState extends State<ShakeOnce> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(vsync: this, duration: PrismDurations.base);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onShake);
  }

  @override
  void didUpdateWidget(ShakeOnce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onShake);
      widget.controller.addListener(_onShake);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) _animation.value = 0;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onShake);
    _animation.dispose();
    super.dispose();
  }

  void _onShake() {
    if (widget.controller.target != widget.target || context.reduceMotion) return;
    _animation.forward(from: 0);
  }

  double get _value {
    final double t = _animation.value;
    final double eased = t < .5 ? PrismCurves.enter.transform(t * 2) : 1 - PrismCurves.exit.transform((t - .5) * 2);
    return eased * widget.distance;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final double v = _value;
        final Widget Function(BuildContext, double, Widget?)? builder = widget.builder;
        if (builder != null) return builder(context, v, child);
        return Padding(
          padding: EdgeInsets.symmetric(vertical: v / 2, horizontal: v),
          child: child,
        );
      },
    );
  }
}
