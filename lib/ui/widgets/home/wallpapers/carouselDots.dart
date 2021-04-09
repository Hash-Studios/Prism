import 'package:flutter/material.dart';

class CarouselDots extends StatelessWidget {
  const CarouselDots({
    Key? key,
    required int current,
  })  : _current = current,
        super(key: key);

  final int _current;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [0, 1, 2, 3, 4].map((i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: _current == i ? 12.0 : 7.0,
            height: 7.0,
            margin: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 2.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(500),
              color: _current == i
                  ? Theme.of(context).errorColor == Colors.black
                      ? Colors.white
                      : Theme.of(context).errorColor
                  : Theme.of(context).errorColor == Colors.black
                      ? Colors.white38
                      : Theme.of(context).errorColor.withOpacity(0.38),
            ),
          );
        }).toList(),
      ),
    );
  }
}
