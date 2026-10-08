import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:flutter/material.dart';

/// The `For you | Latest | Following | Popular` chips, pinned under the feed title.
class HomeChipRailDelegate extends SliverPersistentHeaderDelegate {
  const HomeChipRailDelegate({required this.selected, required this.onSelected});

  final HomeFeedChip selected;
  final ValueChanged<HomeFeedChip> onSelected;

  static const double _height = 52;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: <Widget>[
          for (final HomeFeedChip chip in HomeFeedChip.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(chip.label),
                selected: chip == selected,
                onSelected: (_) {
                  PrismHaptics.tap();
                  onSelected(chip);
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(HomeChipRailDelegate oldDelegate) => oldDelegate.selected != selected;
}
