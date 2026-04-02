import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

class PremiumBanner extends StatelessWidget {
  final bool comparator;
  final Widget child;

  const PremiumBanner({super.key, required this.comparator, required this.child});

  @override
  Widget build(BuildContext context) {
    return comparator
        ? child
        : Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: <Widget>[
              child,
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(color: Color(0xFFFFB800), borderRadius: BorderRadius.zero),
                  padding: EdgeInsets.zero,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Icon(JamIcons.star_f, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          );
  }
}
