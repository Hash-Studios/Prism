import 'package:flutter/material.dart';

class ArrowBounceAnimation extends StatefulWidget {
  final Function? onTap;
  final Widget? child;

  const ArrowBounceAnimation({this.child, this.onTap});

  @override
  _ArrowBounceAnimationState createState() => _ArrowBounceAnimationState();
}

class _ArrowBounceAnimationState extends State<ArrowBounceAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> animation;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 600,
      ),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    animation = Tween(begin: 0.0, end: 0.3)
        .chain(CurveTween(curve: Curves.easeInCubic))
        .animate(_controller);
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.removeListener(() {});
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double scale = 1.3 - animation.value;
    return Transform.scale(
      scale: scale,
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
            color: Colors.transparent,
            height: 250,
            width: 40,
            child: widget.child),
      ),
    );
  }

  void _onTap() {
    if (widget.onTap != null) widget.onTap!();
  }
}
