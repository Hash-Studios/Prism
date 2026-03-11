import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart' as floating;

class BottomBar extends StatelessWidget {
  final Widget? child;
  const BottomBar({this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return floating.BottomBar(
      iconTooltip: 'Scroll to top',
      iconDecoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary, shape: BoxShape.circle),
      barDecoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(500)),
      child: const PrismBottomNav(),
      body: (context, controller) =>
          PrimaryScrollController(controller: controller, child: child ?? const SizedBox.shrink()),
    );
  }
}
