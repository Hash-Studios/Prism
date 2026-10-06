import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

class LiveStylePicker<T> extends StatelessWidget {
  const LiveStylePicker({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.isLocked,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final bool Function(T value) isLocked;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final T value in values)
          ChoiceChip(
            avatar: isLocked(value) ? Icon(Icons.lock_outline_rounded, size: 16, color: scheme.secondary) : null,
            label: Text(label(value)),
            selected: value == selected,
            selectedColor: scheme.error,
            labelStyle: TextStyle(
              color: value == selected ? scheme.onError : scheme.secondary,
              fontFamily: PrismFonts.proximaNova,
              fontWeight: value == selected ? FontWeight.bold : FontWeight.normal,
            ),
            onSelected: (_) {
              PrismHaptics.selection();
              onSelected(value);
            },
          ),
      ],
    );
  }
}
