import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';

/// A quiet row in the detail panel that tells how to get the Lock Screen Depth Effect with this wall.
class DepthEffectRow extends StatelessWidget {
  const DepthEffectRow({super.key, required this.tier});

  final WallDepthTier tier;

  static String _subtitleFor(WallDepthTier tier) => switch (tier) {
    WallDepthTier.auto => 'Your subject sits in front of the clock.',
    WallDepthTier.menu => 'In the Lock Screen editor, tap ••• then Depth\u00A0Effect.',
    WallDepthTier.none => '',
  };

  @override
  Widget build(BuildContext context) {
    return PrismRow(
      icon: Icons.layers_rounded,
      title: 'Depth Effect',
      subtitle: _subtitleFor(tier),
      padding: EdgeInsets.zero,
    );
  }
}
