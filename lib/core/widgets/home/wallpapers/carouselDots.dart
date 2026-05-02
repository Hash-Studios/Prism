import 'package:flutter/material.dart';

class CarouselDots extends StatelessWidget {
  const CarouselDots({super.key, required int current}) : _current = current;

  final int _current;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [0, 1, 2, 3, 4, 5].map((i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: 6.0,
            height: 6.0,
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(500),
              color: _current == i ? Colors.white : Colors.white38,
            ),
          );
        }).toList(),
      ),
    );
  }
}
