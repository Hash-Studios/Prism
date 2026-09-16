import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

class PremiumBanner extends StatelessWidget {
  final bool comparator;
  final Widget child;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final BorderRadius borderRadius;
  final double? iconSize;
  final EdgeInsets iconPadding;
  final StackFit fit;
  final Clip clipBehavior;

  const PremiumBanner({
    super.key,
    required this.comparator,
    required this.child,
    this.top,
    this.left,
    this.right = 0,
    this.bottom = 0,
    this.borderRadius = BorderRadius.zero,
    this.iconSize = 18,
    this.iconPadding = const EdgeInsets.fromLTRB(8, 6, 8, 6),
    this.fit = StackFit.expand,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    return comparator
        ? child
        : Stack(
            fit: fit,
            clipBehavior: clipBehavior,
            children: <Widget>[
              child,
              Positioned(
                top: top,
                left: left,
                right: right,
                bottom: bottom,
                child: Container(
                  decoration: BoxDecoration(color: const Color(0xFFFFB800), borderRadius: borderRadius),
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: iconPadding,
                    child: Icon(JamIcons.star_f, color: Colors.white, size: iconSize),
                  ),
                ),
              ),
            ],
          );
  }
}
