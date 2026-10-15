import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:flutter/material.dart';

/// The `For you | Latest | Following | Popular` chips, pinned under the feed title.
class HomeChipRailDelegate extends SliverPersistentHeaderDelegate {
  const HomeChipRailDelegate({required this.selected, required this.onSelected});

  final HomeFeedChip selected;
  final ValueChanged<HomeFeedChip> onSelected;

  static const double _height = 56;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.5,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: PrismWallGrid.margin + 4, vertical: PrismSpace.xxs),
          children: <Widget>[
            for (final HomeFeedChip chip in HomeFeedChip.values)
              Padding(
                padding: EdgeInsetsDirectional.only(end: chip == HomeFeedChip.values.last ? 0 : PrismSpace.xs),
                child: Center(
                  child: PrismChip(label: chip.label, selected: chip == selected, onTap: () => onSelected(chip)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(HomeChipRailDelegate oldDelegate) => oldDelegate.selected != selected;
}
