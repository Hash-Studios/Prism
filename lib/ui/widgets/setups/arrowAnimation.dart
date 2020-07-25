import 'package:flutter/cupertino.dart';

class ArrowBounceAnimation extends StatefulWidget {
  final Function onTap;
  final Widget child;

  ArrowBounceAnimation({this.child, this.onTap});

  @override
  _ArrowBounceAnimationState createState() => _ArrowBounceAnimationState();
}

class _ArrowBounceAnimationState extends State<ArrowBounceAnimation>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 1000,
      ),
      lowerBound: 0.0,
      upperBound: 0.2,
    )..addListener(() {
        if (mounted) setState(() {});
      });
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
    double scale = 1.2 - _controller.value;
    return GestureDetector(
      onTap: _onTap,
      child: Transform.scale(
        scale: scale,
        child: Container(child: widget.child),
      ),
    );
  }

  void _onTap() {
    if (widget.onTap != null) widget.onTap();
  }
}
