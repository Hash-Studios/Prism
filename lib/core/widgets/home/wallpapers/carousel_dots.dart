import 'package:flutter/material.dart';

class CarouselDots extends StatelessWidget {
  const CarouselDots({super.key, required this.current, required this.count});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(count, (i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: 6.0,
            height: 6.0,
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(500),
              color: current == i ? Colors.white : Colors.white38,
            ),
          );
        }),
      ),
    );
  }
}
