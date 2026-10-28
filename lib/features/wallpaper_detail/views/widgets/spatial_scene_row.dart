import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/wallpaper/wall_spatial.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

class SpatialSceneRow extends StatelessWidget {
  const SpatialSceneRow({super.key, required this.tier, required this.wallId});

  final WallSpatialTier tier;
  final String wallId;

  String _subtitleFor(WallSpatialTier tier, BuildContext context) => switch (tier) {
    WallSpatialTier.great => context.l10n.wallpaperSpatialGreatSubtitle,
    WallSpatialTier.ok => context.l10n.wallpaperSpatialOkSubtitle,
    WallSpatialTier.none => '',
  };

  @override
  Widget build(BuildContext context) {
    return PrismRow(
      icon: Icons.view_in_ar_rounded,
      title: context.l10n.wallpaperSpatialScene,
      subtitle: _subtitleFor(tier, context),
      padding: EdgeInsets.zero,
      onTap: () => showSpatialSceneGuide(context, wallId: wallId, tier: tier),
    );
  }
}
