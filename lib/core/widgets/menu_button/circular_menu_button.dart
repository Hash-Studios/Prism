import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:flutter/material.dart';

/// Shared skeleton for the circular action buttons on the wallpaper detail menu:
/// a primary-color circle with a soft drop shadow around [child], plus a loading
/// spinner overlay while [isLoading] is true.
class CircularMenuButton extends StatelessWidget {
  const CircularMenuButton({
    super.key,
    required this.label,
    required this.child,
    this.onTap,
    required this.isLoading,
    this.padding = const EdgeInsets.all(17),
    this.selected,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool isLoading;
  final EdgeInsets padding;

  /// For toggle actions such as Favourite, so screen readers announce the current state.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final Widget button = Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 4, offset: const Offset(0, 4)),
            ],
            borderRadius: BorderRadius.circular(500),
          ),
          padding: padding,
          child: child,
        ),
        Positioned(
          top: 0,
          left: 0,
          height: 53,
          width: 53,
          child: AnimatedSwitcher(
            duration: context.motion(const Duration(milliseconds: 120)),
            child: isLoading
                ? const CircularProgressIndicator(key: ValueKey<bool>(true), strokeWidth: 2)
                : const SizedBox.shrink(key: ValueKey<bool>(false)),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      label: label,
      selected: selected,
      child: onTap == null
          ? button
          : GestureDetector(
              onTap: onTap,
              child: PressScale(child: button),
            ),
    );
  }
}
