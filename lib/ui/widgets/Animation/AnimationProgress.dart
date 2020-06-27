import 'dart:math';

import 'package:flutter/material.dart';

class AnimationProgress extends StatefulWidget {
  @override
  _AnimationProgressState createState() => _AnimationProgressState();
}

class _AnimationProgressState extends State<AnimationProgress>
    with SingleTickerProviderStateMixin {
  double _scale;
  AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 500,
      ),
      lowerBound: 0.0,
      upperBound: 1.0,
    )
      ..repeat(period: Duration(milliseconds: 700), reverse: false)
      ..addListener(() {
        setState(() {});
      });
    }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double height = 100;
    double width = 60;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: width * 0.8,
          height: width * 0.8,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50000), color: Colors.grey),
          child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
            return Transform.rotate(
              angle: 2 * pi * _controller.value,
              child: Container(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          margin: EdgeInsets.all(width * 0.03),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50000),
                              color: Colors.black),
                          width: width * 0.1,
                          height: width * 0.1,
                        ),
                        Container(
                          margin: EdgeInsets.all(width * 0.03),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5000),
                              color: Colors.black),
                          width: width * 0.1,
                          height: width * 0.1,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          margin: EdgeInsets.all(width * 0.03),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5000),
                              color: Colors.black),
                          width: width * 0.1,
                          height: width * 0.1,
                        ),
                        Container(
                          margin: EdgeInsets.all(width * 0.03),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5000),
                              color: Colors.black),
                          width: width * 0.1,
                          height: width * 0.1,
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          }),
        )
      ],
    );
//    Transform.scale(scale: _controller.value,child: Transform.rotate(angle:2* pi*_controller.value,child: Container(height: 100,width: 100,color: Colors.black,),))
  }

//  Widget _customWidget(double maxHeight, double maxWidth) {
//    return ;
//  }
}
