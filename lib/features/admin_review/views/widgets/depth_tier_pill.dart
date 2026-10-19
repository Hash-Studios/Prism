import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/depth_override.dart';
import 'package:flutter/material.dart';

/// "Depth: Auto" on a review card, in the style of the category pill. A tap opens a menu that overrides the tier
/// the detector chose. [tier] is null when the wall was not checked.
class DepthTierPill extends StatelessWidget {
  const DepthTierPill({super.key, required this.tier, required this.onChanged});

  final WallDepthTier? tier;
  final ValueChanged<WallDepthTier> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextStyle onImage = PrismTextStyles.caption(
      context,
    ).copyWith(color: Colors.white, fontWeight: FontWeight.w700);
    return PopupMenuButton<WallDepthTier>(
      tooltip: 'Change Depth Effect',
      initialValue: tier,
      onSelected: (WallDepthTier picked) {
        PrismHaptics.selection();
        onChanged(picked);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<WallDepthTier>>[
        for (final WallDepthTier option in WallDepthTier.values)
          PopupMenuItem<WallDepthTier>(value: option, child: Text(depthTierLabel(option))),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PrismSpace.xs),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(PrismRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: PrismSpace.sm, right: PrismSpace.xxs, top: 5, bottom: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Depth: ${depthTierLabel(tier)}', style: onImage),
                const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
