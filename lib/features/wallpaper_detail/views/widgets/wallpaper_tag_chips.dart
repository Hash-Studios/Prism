import 'package:flutter/material.dart';

/// Tag chips that open a search for the tapped tag.
class WallpaperTagChips extends StatelessWidget {
  const WallpaperTagChips({required this.tags, required this.onTagTap, super.key});

  final List<String> tags;
  final ValueChanged<String> onTagTap;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      children: <Widget>[
        for (final String tag in tags)
          ActionChip(label: Text(tag), tooltip: 'Search $tag', onPressed: () => onTagTap(tag)),
      ],
    );
  }
}
