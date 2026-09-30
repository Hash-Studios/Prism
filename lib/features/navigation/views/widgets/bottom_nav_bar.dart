import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:Prism/features/navigation/views/widgets/prism_fab.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart' as floating;

class BottomBar extends StatelessWidget {
  final Widget? child;
  const BottomBar({this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return floating.BottomBar(
      layout: floating.BottomBarLayout(
        width: MediaQuery.of(context).size.width,
        borderRadius: BorderRadius.circular(500),
        fit: StackFit.expand,
      ),
      theme: floating.BottomBarThemeData(
        barDecoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(500)),
        iconDecoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
        iconWidth: 32,
        iconHeight: 32,
      ),
      iconTooltip: 'Scroll to top',
      icon: (width, height) => const Icon(JamIcons.arrow_up, color: Colors.white, size: 16),
      body: child ?? const SizedBox.shrink(),
      child: const Align(
        heightFactor: 1.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicWidth(child: PrismBottomNav()),
            SizedBox(width: 12),
            PrismFab(),
          ],
        ),
      ),
    );
  }
}
