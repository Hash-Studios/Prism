import 'package:Prism/core/widgets/premium_banners/premium_banner.dart';
import 'package:flutter/material.dart';

/// Premium star pinned to the bottom-right corner of whatever tile it wraps, at any column count.
class PremiumCornerBanner extends StatelessWidget {
  const PremiumCornerBanner({super.key, required this.isPremiumWall, required this.child});

  /// When false the [child] is shown without the star.
  final bool isPremiumWall;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PremiumBanner(
      comparator: !isPremiumWall,
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(12)),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}
