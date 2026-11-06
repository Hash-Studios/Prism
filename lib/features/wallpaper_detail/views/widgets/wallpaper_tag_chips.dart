import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Compact tag chips that open a search for the tapped tag. The first [maxShown] show, then a "+N" chip that shows
/// the rest.
class WallpaperTagChips extends StatefulWidget {
  const WallpaperTagChips({required this.tags, required this.onTagTap, super.key});

  static const int maxShown = 8;

  final List<String> tags;
  final ValueChanged<String> onTagTap;

  @override
  State<WallpaperTagChips> createState() => _WallpaperTagChipsState();
}

class _WallpaperTagChipsState extends State<WallpaperTagChips> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final List<String> tags = widget.tags;
    if (tags.isEmpty) return const SizedBox.shrink();
    final int hidden = _all ? 0 : tags.length - WallpaperTagChips.maxShown;
    return Wrap(
      spacing: PrismSpace.xs,
      children: <Widget>[
        for (final String tag in hidden > 0 ? tags.take(WallpaperTagChips.maxShown) : tags)
          Tooltip(
            message: context.l10n.wallpaperSearchTag(tag),
            child: PrismChip(label: tag, compact: true, onTap: () => widget.onTagTap(tag)),
          ),
        if (hidden > 0)
          Tooltip(
            message: context.l10n.coreSeeMore,
            child: PrismChip(label: '+$hidden', compact: true, onTap: () => setState(() => _all = true)),
          ),
      ],
    );
  }
}
