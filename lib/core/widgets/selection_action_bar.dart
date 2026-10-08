import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

/// Top row shown while a grid is in multi-select mode: a close button and the selected count.
class SelectionHeader extends StatelessWidget {
  const SelectionHeader({super.key, required this.count, required this.onCancel, this.hint});

  final int count;
  final VoidCallback onCancel;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 16, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cancel selection',
            icon: Icon(JamIcons.close, color: theme.colorScheme.secondary),
            onPressed: onCancel,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count selected',
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.secondary),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.75),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom row of actions for a multi-select grid. Pass circular menu buttons as [actions].
class SelectionActionBar extends StatelessWidget {
  const SelectionActionBar({super.key, required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: actions),
      ),
    );
  }
}
