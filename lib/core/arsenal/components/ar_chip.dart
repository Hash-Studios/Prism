import 'package:Prism/core/arsenal/colors.dart';
import 'package:Prism/core/arsenal/spacing.dart';
import 'package:Prism/core/arsenal/typography.dart';
import 'package:flutter/material.dart';

class ArChip extends StatelessWidget {
  const ArChip({super.key, required this.label, this.onTap, this.selected = false});

  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: ArsenalSpacing.chipHeight,
        padding: const EdgeInsets.symmetric(horizontal: ArsenalSpacing.md),
        decoration: BoxDecoration(
          color: selected ? ArsenalColors.accent : ArsenalColors.surface,
          border: selected ? null : Border.all(color: ArsenalColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: ArsenalTypography.label.copyWith(color: selected ? Colors.white : ArsenalColors.onSurface),
        ),
      ),
    );
  }
}
