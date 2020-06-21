import 'package:flutter/material.dart';
import 'dart:math' as math;

class OnboardPageIndicator extends StatelessWidget {
  const OnboardPageIndicator({
    Key key,
    @required this.index,
  }) : super(key: key);

  final int index;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'Onboard',
      transitionOnUserGestures: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Transform.rotate(
              angle: math.pi / 4.0,
              child: index == 1
                  ? Container(
                      width: 10,
                      height: 10,
                      color: Colors.white,
                    )
                  : Container(
                      width: 9,
                      height: 9,
                      color: Colors.white38,
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Transform.rotate(
              angle: math.pi / 4.0,
              child: index == 2
                  ? Container(
                      width: 10,
                      height: 10,
                      color: Colors.white,
                    )
                  : Container(
                      width: 9,
                      height: 9,
                      color: Colors.white38,
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Transform.rotate(
              angle: math.pi / 4.0,
              child: index == 3
                  ? Container(
                      width: 10,
                      height: 10,
                      color: Colors.white,
                    )
                  : Container(
                      width: 9,
                      height: 9,
                      color: Colors.white38,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}