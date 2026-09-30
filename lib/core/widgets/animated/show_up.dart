// Dart
import 'dart:async';

// Flutter
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:flutter/material.dart';

enum SlideFromSlide { top, bottom, left, right }

class ShowUpTransition extends StatefulWidget {
  /// [child] to be Animated
  final Widget child;

  /// Animation Duration, default is 220 Milliseconds
  final Duration? duration;

  /// Delay before starting Animation, default is Zero
  final Duration? delay;

  /// Bring forward/reverse the Animation
  final bool forward;

  /// From which direction start the [Slide] animation
  final SlideFromSlide slideSide;

  const ShowUpTransition({
    required this.child,
    this.duration,
    this.delay,
    this.slideSide = SlideFromSlide.left,
    required this.forward,
  });

  @override
  _ShowUpTransitionState createState() => _ShowUpTransitionState();
}

class _ShowUpTransitionState extends State<ShowUpTransition> with SingleTickerProviderStateMixin {
  static const double _distance = 8;

  late AnimationController _animController;
  late Animation<double> _curve;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: widget.duration ?? const Duration(milliseconds: 220));
    _curve = CurvedAnimation(parent: _animController, curve: PrismCurves.enter, reverseCurve: PrismCurves.exit);
    _start();
  }

  @override
  void didUpdateWidget(ShowUpTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forward != widget.forward) {
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer(widget.delay ?? Duration.zero, () {
      if (!mounted) return;
      if (context.reduceMotion) {
        _animController.value = widget.forward ? 1 : 0;
      } else if (widget.forward) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Offset get _from => switch (widget.slideSide) {
    SlideFromSlide.left => const Offset(-_distance, 0),
    SlideFromSlide.right => const Offset(_distance, 0),
    SlideFromSlide.bottom => const Offset(0, _distance),
    SlideFromSlide.top => const Offset(0, -_distance),
  };

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.forward,
      child: FadeTransition(
        opacity: _curve,
        child: AnimatedBuilder(
          animation: _curve,
          builder: (context, child) => Transform.translate(offset: _from * (1 - _curve.value), child: child),
          child: widget.child,
        ),
      ),
    );
  }
}
