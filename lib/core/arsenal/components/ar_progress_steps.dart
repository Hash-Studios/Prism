import 'package:Prism/core/arsenal/colors.dart';
import 'package:Prism/core/arsenal/spacing.dart';
import 'package:flutter/material.dart';

class ArProgressSteps extends StatelessWidget {
  const ArProgressSteps({super.key, required this.total, required this.current});

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (index) {
        final isActive = index == current;
        return Padding(
          padding: const EdgeInsets.only(right: ArsenalSpacing.xs),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(color: isActive ? ArsenalColors.accent : ArsenalColors.muted),
          ),
        );
      }),
    );
  }
}
