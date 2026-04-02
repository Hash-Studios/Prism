import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

class PremiumBanner extends StatelessWidget {
  final bool comparator;
  final Widget child;

  /// Tile size in the parent grid (used to position the premium chip for any column count).
  final double cardWidth;
  final double cardHeight;

  const PremiumBanner({
    super.key,
    required this.comparator,
    required this.child,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    return comparator
        ? child
        : Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              child,
              Positioned(
                top: cardHeight - 142,
                left: cardWidth - 102.5,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFB800),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                  ),
                  padding: EdgeInsets.zero,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                    child: Icon(JamIcons.star_f, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
  }
}
