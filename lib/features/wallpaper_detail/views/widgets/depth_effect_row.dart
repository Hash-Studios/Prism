import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

class DepthEffectRow extends StatelessWidget {
  const DepthEffectRow({super.key, required this.tier});

  final WallDepthTier tier;

  String _subtitleFor(WallDepthTier tier, BuildContext context) => switch (tier) {
    WallDepthTier.auto => context.l10n.wallpaperDepthSubjectSubtitle,
    WallDepthTier.menu => context.l10n.wallpaperDepthEditorSubtitle,
    WallDepthTier.none => '',
  };

  @override
  Widget build(BuildContext context) {
    return PrismRow(
      icon: Icons.layers_rounded,
      title: context.l10n.wallpaperDepthEffect,
      subtitle: _subtitleFor(tier, context),
      padding: EdgeInsets.zero,
    );
  }
}
