import 'package:Prism/theme/darkThemeModel.dart';
import 'package:Prism/theme/theme.dart';
import 'package:Prism/theme/themeModeProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Loader extends StatefulWidget {
  @override
  _LoaderState createState() => _LoaderState();
}

class _LoaderState extends State<Loader> with TickerProviderStateMixin {
  AnimationController _controller;
  Animation<double> animation;
  AnimationController _controller2;
  Animation<double> animation2;

  @override
  void initState() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    animation = TweenSequence<double>([
      TweenSequenceItem(
        weight: 1.0,
        tween: Tween(
          begin: 0,
          end: 1,
        ),
      ),
    ]).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_controller)
      ..addListener(() {
        setState(() {});
      });
    _controller.repeat();
    _controller2 = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    animation2 = TweenSequence<double>([
      TweenSequenceItem(
        weight: 1.0,
        tween: Tween(
          begin: 1,
          end: 0,
        ),
      ),
    ]).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_controller2)
      ..addListener(() {
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
            color: Provider.of<ThemeModeExtended>(context).getCurrentModeStyle(
                            MediaQuery.of(context).platformBrightness) ==
                        "Dark" &&
                    Provider.of<DarkThemeModel>(context).currentTheme ==
                        kDarkTheme2
                ? Theme.of(context).errorColor == Colors.black
                    ? Theme.of(context).accentColor
                    : Theme.of(context).errorColor
                : Theme.of(context).errorColor,
          ),
          child: const SizedBox(
            width: 45,
            height: 45,
          ),
        ),
      ),
    );
  }
}
