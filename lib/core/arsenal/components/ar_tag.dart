import 'package:Prism/core/arsenal/colors.dart';
import 'package:Prism/core/arsenal/spacing.dart';
import 'package:Prism/core/arsenal/typography.dart';
import 'package:flutter/material.dart';

class ArTag extends StatelessWidget {
  const ArTag({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? ArsenalColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ArsenalSpacing.sm, vertical: ArsenalSpacing.xs),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.15),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        label.toUpperCase(),
        style: ArsenalTypography.monoHighlight.copyWith(color: effectiveColor, fontSize: 11),
      ),
    );
  }
}
