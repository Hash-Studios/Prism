import 'package:flutter/material.dart';

/// Tag chips that open a search for the tapped tag. The fill is solid, blended over the panel colour, so a tag reads
/// the same whatever shows through the panel.
class WallpaperTagChips extends StatelessWidget {
  const WallpaperTagChips({required this.tags, required this.onTagTap, super.key});

  final List<String> tags;
  final ValueChanged<String> onTagTap;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    final ChipThemeData chipTheme = ChipTheme.of(context);
    final Color? tonalFill = chipTheme.backgroundColor;
    return Wrap(
      spacing: 8,
      children: <Widget>[
        for (final String tag in tags)
          ActionChip(
            label: Text(tag),
            tooltip: 'Search $tag',
            onPressed: () => onTagTap(tag),
            backgroundColor: tonalFill == null
                ? null
                : Color.alphaBlend(tonalFill, theme.colorScheme.surfaceContainerLow),
            labelStyle: chipTheme.labelStyle?.copyWith(fontWeight: FontWeight.w500),
          ),
      ],
    );
  }
}
