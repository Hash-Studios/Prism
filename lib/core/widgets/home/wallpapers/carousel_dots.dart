import 'package:Prism/core/motion/prism_motion.dart';
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
          final bool active = current == i;
          return AnimatedContainer(
            duration: context.motion(const Duration(milliseconds: 250)),
            curve: Curves.easeOutCubic,
            width: active ? 16.0 : 6.0,
            height: 6.0,
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(500),
              color: active ? Colors.white : Colors.white54,
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))],
            ),
          );
        }),
      ),
    );
  }
}
