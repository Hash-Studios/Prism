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
  Color color;
  Color color2;
  bool isOpen;
  String link = "";
  String thumb = "";
  String views = "";
  String resolution = "";
  String url = "";
  String createdAt = "";
  String favourites = "";
  RadialMenu(this.color, this.color2, this.isOpen, this.link, this.thumb,
      this.views, this.resolution, this.url, this.createdAt, this.favourites);
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
    return RadialAnimation(
        controller: controller,
        color: widget.color,
        color2: widget.color2,
        isOpen: widget.isOpen,
        link: widget.link,
        thumb: widget.thumb,
        views: widget.views,
        resolution: widget.resolution,
        url: widget.url,
        createdAt: widget.createdAt,
        favourites: widget.favourites);
  }
}

// The Animation
class RadialAnimation extends StatelessWidget {
  final AnimationController controller;
  final Animation<double> scale;
  final Animation<double> scale2;
  final Animation<double> translation;
  final Animation<double> rotation;
  Color color;
  Color color2;
  bool isOpen;
  String link = "";
  String thumb = "";
  String views = "";
  String resolution = "";
  String url = "";
  String createdAt = "";
  String favourites = "";
  RadialAnimation(
      {Key key,
      this.controller,
      this.color,
      this.color2,
      this.isOpen,
      this.link,
      this.thumb,
      this.views,
      this.resolution,
      this.url,
      this.createdAt,
      this.favourites})
      : scale = Tween<double>(
          begin: 1.3,
          end: 0.0,
        ).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOutSine),
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
            children: [
              SizedBox(
                height: 1060.h,
                width: 720.w,
              ),
              Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  SizedBox(
                    height: 500.h,
                  ),
                  Transform(
                    transform: Matrix4.identity()
                      ..translate(0.1, -(translation.value) * 3.5),
                    child: Transform.scale(
                      scale: 1.3 - scale.value,
                      child: Card(
                        color: color,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        elevation: 8,
                        child: SizedBox(
                          height: 400.h,
                          width: 500.w,
                          child: Container(
                            padding:
                                EdgeInsets.fromLTRB(60.w, 20.w, 60.w, 20.w),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Icon(
                                        Icons.remove_red_eye,
                                        color: color2,
                                      ),
                                      Text(
                                        "$views",
                                        style: TextStyle(
                                          color: color2,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Icon(
                                        Icons.favorite,
                                        color: color2,
                                      ),
                                      Text(
                                        "$favourites",
                                        style: TextStyle(
                                          color: color2,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Icon(
                                        Icons.photo_size_select_large,
                                        color: color2,
                                      ),
                                      Text(
                                        "$resolution",
                                        style: TextStyle(
                                          color: color2,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Icon(
                                        Icons.link,
                                        color: color2,
                                      ),
                                      Text(
                                        "$url",
                                        style: TextStyle(
                                          color: color2,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Icon(
                                        Icons.calendar_today,
                                        color: color2,
                                      ),
                                      Text(
                                        "$createdAt",
                                        style: TextStyle(
                                          color: color2,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildButtonR(215,
                      color: color,
                      color2: color2,
                      icon: Icons.add,
                      func: _close),
                  _buildButton(270,
                      color: color,
                      color2: color2,
                      icon: Icons.save_alt,
                      func: _close),
                  _buildButton(325,
                      color: color,
                      color2: color2,
                      icon: Icons.favorite,
                      func: _close),
                  Transform.scale(
                    scale: 1.3 -
                        scale
                            .value, // subtract the beginning value to run the opposite animation
                    child: FloatingActionButton(
                        heroTag: 1,
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
                        heroTag: 2,
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

  _buildButton(double angle,
      {Color color, Color color2, IconData icon, Function func}) {
    final double rad = radians(angle);
    return Transform.scale(
      scale: 0.9 - scale2.value,
      child: Transform(
          transform: Matrix4.identity()
            ..translate((translation.value) * cos(rad) * 1.2,
                (translation.value) * sin(rad) * 1.2),
          child: FloatingActionButton(
              heroTag: 3 * angle,
              child: Icon(
                icon,
                color: color2,
              ),
              backgroundColor: color,
              onPressed: func,
              elevation: 8)),
    );
  }

  _buildButtonR(double angle,
      {Color color, Color color2, IconData icon, Function func}) {
    final double rad = radians(angle);
    return Transform.scale(
      scale: 0.9 - scale2.value,
      child: Transform(
          transform: Matrix4.identity()
            ..translate((translation.value) * cos(rad) * 1.2,
                (translation.value) * sin(rad) * 1.2),
          child: FloatingActionButton(
              heroTag: 5 * angle,
              child: Transform.rotate(
                angle: 45 * pi / 180,
                child: Icon(
                  icon,
                  color: color2,
                ),
              ),
              backgroundColor: color,
              onPressed: func,
              elevation: 8)),
    );
  }
}
