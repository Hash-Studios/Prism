import 'package:Prism/core/motion/prism_motion.dart';
import 'package:flutter/widgets.dart';

/// Scales [child] down while a pointer is down on it. Uses a [Listener], so the child still gets its own taps.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.96, this.enabled = true});

  final Widget child;

  /// Scale while pressed.
  final double scale;

  /// When false, the child is shown as is.
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: PrismDurations.press,
      reverseDuration: const Duration(milliseconds: 80),
    );
    _scale = Tween<double>(
      begin: 1,
      end: widget.scale,
    ).animate(CurvedAnimation(parent: _controller, curve: PrismCurves.exit, reverseCurve: PrismCurves.enter));
  }

  @override
  void didUpdateWidget(PressScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _controller.value != 0) _controller.value = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) _controller.value = 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (!mounted || !widget.enabled || context.reduceMotion) return;
    pressed ? _controller.forward() : _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, filterQuality: FilterQuality.low, child: child),
        child: widget.child,
      ),
    );
  }
}
