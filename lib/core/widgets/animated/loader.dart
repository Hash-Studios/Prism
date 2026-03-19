import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:flutter/material.dart';

class Loader extends StatefulWidget {
  @override
  _LoaderState createState() => _LoaderState();
}

class _LoaderState extends State<Loader> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> animation;
  late AnimationController _controller2;
  late Animation<double> animation2;

  @override
  void initState() {
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    animation =
        TweenSequence<double>([
          TweenSequenceItem(weight: 1.0, tween: Tween(begin: 0, end: 1)),
        ]).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_controller)..addListener(() {
          setState(() {});
        });
    _controller.repeat();
    _controller2 = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    animation2 =
        TweenSequence<double>([
          TweenSequenceItem(weight: 1.0, tween: Tween(begin: 1, end: 0)),
        ]).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_controller2)..addListener(() {
          setState(() {});
        });
    _controller2.repeat();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    _controller2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: animation.value,
      child: Opacity(
        opacity: animation2.value,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.prismModeStyleForContext() == "Dark" && context.prismIsAmoledDark()
                ? Theme.of(context).colorScheme.error == Colors.black
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.error,
          ),
          child: const SizedBox(width: 45, height: 45),
        ),
      ),
    );
  }
}
