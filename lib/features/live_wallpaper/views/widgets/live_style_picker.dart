import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/theme/contrast.dart';
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
    final Color onAccent = onColor(Theme.of(context).colorScheme.primary);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        for (final T value in values)
          ChoiceChip(
            avatar: isLocked(value)
                ? Icon(Icons.lock_outline_rounded, color: value == selected ? onAccent : null)
                : null,
            label: Text(label(value)),
            selected: value == selected,
            onSelected: (_) {
              PrismHaptics.selection();
              onSelected(value);
            },
          ),
      ],
    );
  }
}
