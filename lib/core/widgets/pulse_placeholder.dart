import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:flutter/material.dart';

/// Owns one shimmer controller for a whole skeleton area. [builder] runs once per rebuild of the parent, not per
/// frame; the pulse is painted by [PulseFill] leaves below it. Under reduce motion the fills stay still.
class PulsePlaceholder extends StatefulWidget {
  const PulsePlaceholder({super.key, required this.builder});

  /// [color] is the resting skeleton colour, for callers that need a plain colour.
  final Widget Function(BuildContext context, Color color) builder;

  @override
  State<PulsePlaceholder> createState() => _PulsePlaceholderState();
}

class _PulsePlaceholderState extends State<PulsePlaceholder> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(duration: PrismDurations.shimmer, vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (Color from, Color to) = context.isDarkMode
        ? (Colors.white10, const Color(0x22FFFFFF))
        : (Colors.black.withValues(alpha: .1), Colors.black.withValues(alpha: .14));
    final Animation<Color?> color = ColorTween(
      begin: from,
      end: to,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_controller);
    return _PulseScope(
      color: color,
      fallback: from,
      child: Builder(builder: (context) => widget.builder(context, from)),
    );
  }
}

class _PulseScope extends InheritedWidget {
  const _PulseScope({required this.color, required this.fallback, required super.child});

  final Animation<Color?> color;
  final Color fallback;

  @override
  bool updateShouldNotify(_PulseScope oldWidget) => color != oldWidget.color || fallback != oldWidget.fallback;
}

/// A skeleton block that pulses with the nearest [PulsePlaceholder]. Only this leaf repaints each frame.
/// Without a [PulsePlaceholder] above it, it shows the resting colour.
class PulseFill extends StatelessWidget {
  const PulseFill({super.key, this.borderRadius});

  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final _PulseScope? scope = context.dependOnInheritedWidgetOfExactType<_PulseScope>();
    if (scope == null) {
      final Color rest = context.isDarkMode ? Colors.white10 : Colors.black.withValues(alpha: .1);
      return DecoratedBox(
        decoration: BoxDecoration(color: rest, borderRadius: borderRadius),
      );
    }
    return AnimatedBuilder(
      animation: scope.color,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(color: scope.color.value ?? scope.fallback, borderRadius: borderRadius),
      ),
    );
  }
}
