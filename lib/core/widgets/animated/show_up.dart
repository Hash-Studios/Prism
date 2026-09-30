// Dart
import 'dart:async';

// Flutter
import 'package:flutter/material.dart';

enum SlideFromSlide { top, bottom, left, right }

class ShowUpTransition extends StatefulWidget {
  /// [child] to be Animated
  final Widget child;

  /// Animation Duration, default is 200 Milliseconds
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
  late AnimationController _animController;
  late Animation<Offset> _animOffset;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: widget.duration ?? const Duration(milliseconds: 400));
    final Offset begin = switch (widget.slideSide) {
      SlideFromSlide.left => const Offset(-0.35, 0.0),
      SlideFromSlide.right => const Offset(0.35, 0.0),
      SlideFromSlide.bottom => const Offset(0.0, 0.35),
      SlideFromSlide.top => const Offset(0.0, -0.35),
    };
    _animOffset = Tween<Offset>(
      begin: begin,
      end: Offset.zero,
    ).animate(CurvedAnimation(curve: Curves.fastLinearToSlowEaseIn, parent: _animController));
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
      if (widget.forward) {
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

  @override
  Widget build(BuildContext context) {
    return widget.forward
        ? FadeTransition(
            opacity: _animController,
            child: SlideTransition(position: _animOffset, child: widget.child),
          )
        : Container();
  }
}
