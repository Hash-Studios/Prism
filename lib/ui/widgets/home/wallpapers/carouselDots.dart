import 'package:flutter/material.dart';
import 'package:Prism/theme/config.dart' as config;

class CarouselDots extends StatelessWidget {
  const CarouselDots({
    Key key,
    @required int current,
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
            width: _current == i ? 8.0 : 7.0,
            height: _current == i ? 8.0 : 7.0,
            margin: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 2.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _current == i
                  ? config.Colors().mainAccentColor(1)
                  : config.Colors().mainAccentColor(1).withOpacity(0),
              border: Border.all(
                color: _current == i
                    ? config.Colors().mainAccentColor(1).withOpacity(0)
                    : config.Colors().mainAccentColor(1),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
