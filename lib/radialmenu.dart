import 'package:flutter/material.dart';
import 'dart:math';
import 'package:vector_math/vector_math.dart' show radians;
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// void main() => runApp(MyApp());

// // The parent Material App
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//         home: Scaffold(body: SizedBox.expand(child: RadialMenu())));
//   }
// }

// The stateful widget + animation controller
class RadialMenu extends StatefulWidget {
  createState() => _RadialMenuState();
}

class _RadialMenuState extends State<RadialMenu>
    with SingleTickerProviderStateMixin {
  AnimationController controller;
  @override
  void initState() {
    super.initState();
    controller =
        AnimationController(duration: Duration(milliseconds: 300), vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return RadialAnimation(controller: controller);
  }
}

// The Animation
class RadialAnimation extends StatelessWidget {
  final AnimationController controller;
  final Animation<double> scale;
  final Animation<double> scale2;
  final Animation<double> translation;
  final Animation<double> rotation;

  RadialAnimation({Key key, this.controller})
      : scale = Tween<double>(
          begin: 1.3,
          end: 0.0,
        ).animate(
          CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn),
        ),
        scale2 = Tween<double>(
          begin: 0.9,
          end: 0.0,
        ).animate(
          CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn),
        ),
        translation = Tween<double>(
          begin: 0.0,
          end: 100.0,
        ).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
        ),
        rotation = Tween<double>(
          begin: 0.0,
          end: 360.0,
        ).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(
              0.3,
              0.9,
              curve: Curves.decelerate,
            ),
          ),
        ),
        super(key: key);

  build(context) {
    ScreenUtil.init(context, width: 720, height: 1440);
    return AnimatedBuilder(
        animation: controller,
        builder: (context, builder) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Transform(
                    transform: Matrix4.identity()
                      ..translate(0.1, -(translation.value) * 3.5),
                    child: Transform.scale(
                      scale: 1.3 - scale.value,
                      child: Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          elevation: 8,
                          child: SizedBox(
                            height: 320.h,
                            width: 430.w,
                            child: Icon(Icons.info_outline),
                          )),
                    ),
                  ),
                  _buildButtonR(215,
                      color: Colors.white, icon: Icons.add, func: _close),
                  _buildButton(270,
                      color: Colors.white, icon: Icons.save_alt, func: _close),
                  _buildButton(325,
                      color: Colors.white, icon: Icons.favorite, func: _close),
                  Transform.scale(
                    scale: 1.3 -
                        scale
                            .value, // subtract the beginning value to run the opposite animation
                    child: FloatingActionButton(
                        child: Icon(
                          Icons.format_paint,
                          color: Colors.black,
                        ),
                        onPressed: _close,
                        backgroundColor: Colors.white),
                  ),
                  Transform.scale(
                    scale: scale.value,
                    child: FloatingActionButton(
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.black,
                        ),
                        backgroundColor: Colors.white,
                        onPressed: _open),
                  )
                ],
              ),
            ],
          );
        });
  }

  _open() {
    controller.forward();
  }

  _close() {
    controller.reverse();
  }

  _buildButton(double angle, {Color color, IconData icon, Function func}) {
    final double rad = radians(angle);
    return Transform.scale(
      scale: 0.9 - scale2.value,
      child: Transform(
          transform: Matrix4.identity()
            ..translate((translation.value) * cos(rad) * 1.2,
                (translation.value) * sin(rad) * 1.2),
          child: FloatingActionButton(
              child: Icon(
                icon,
                color: Colors.black,
              ),
              backgroundColor: color,
              onPressed: func,
              elevation: 8)),
    );
  }

  _buildButtonR(double angle, {Color color, IconData icon, Function func}) {
    final double rad = radians(angle);
    return Transform.scale(
      scale: 0.9 - scale2.value,
      child: Transform(
          transform: Matrix4.identity()
            ..translate((translation.value) * cos(rad) * 1.2,
                (translation.value) * sin(rad) * 1.2),
          child: FloatingActionButton(
              child: Transform.rotate(
                angle: 45 * pi / 180,
                child: Icon(
                  icon,
                  color: Colors.black,
                ),
              ),
              backgroundColor: color,
              onPressed: func,
              elevation: 8)),
    );
  }
}
