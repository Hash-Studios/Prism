import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/features/trending/domain/entities/trending_range.dart';
import 'package:Prism/features/trending/views/widgets/boosted_tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Trending tab of the home feed as slivers: the `This week | All time` switch, then the wallpapers in the home
/// grid.
class TrendingChipSliver extends StatelessWidget {
  const TrendingChipSliver({
    super.key,
    required this.bloc,
    required this.crossAxisCount,
    required this.tileMemCacheHeight,
  });

  final TrendingBloc bloc;
  final int crossAxisCount;
  final int tileMemCacheHeight;

  static String _label(TrendingRange range) => switch (range) {
    TrendingRange.week => 'This week',
    TrendingRange.allTime => 'All time',
  };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrendingBloc, TrendingState>(
      bloc: bloc,
      builder: (context, state) {
        return SliverMainAxisGroup(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.sm, PrismSpace.page, PrismSpace.sm),
                child: PrismSegmented<TrendingRange>(
                  values: TrendingRange.values,
                  selected: state.range,
                  labelOf: _label,
                  onChanged: (range) => bloc.add(TrendingEvent.rangeSelected(range)),
                ),
              ),
            ),
            _walls(context, state.current),
          ],
        );
      },
    );
  }

  Widget _walls(BuildContext context, TrendingSection section) {
    if (section.walls.isEmpty) {
      if (section.status == LoadStatus.initial || section.status == LoadStatus.loading) {
        return const SliverToBoxAdapter(child: LoadingCards(useFeedLayout: true));
      }
      final bool failed = section.status == LoadStatus.failure;
      return SliverToBoxAdapter(
        child: GlintState(
          kind: failed ? GlintStateKind.error : GlintStateKind.empty,
          title: failed ? "Couldn't load trending wallpapers" : 'Nothing is trending yet',
          body: failed ? 'Check your connection and try again.' : 'Check back soon.',
          actionLabel: failed ? 'Try again' : null,
          onAction: failed ? () => bloc.add(const TrendingEvent.refreshRequested()) : null,
        ),
      );
    }
    return SliverPadding(
      padding: PrismFeedLayout.gridPadding,
      sliver: SliverGrid(
        gridDelegate: PrismWallGrid.delegate(context, columns: crossAxisCount, spacing: PrismFeedLayout.gridSpacing),
        delegate: SliverChildBuilderDelegate((context, index) {
          final wall = section.walls[index];
          return KeyedSubtree(
            key: ValueKey<String>(wall.id),
            child: WallpaperTile(
              item: PrismFeedItem(id: wall.id, wallpaper: wall),
              index: index,
              crossAxisCount: crossAxisCount,
              memCacheHeight: tileMemCacheHeight,
              quickActions: true,
              sourceContext: 'home_trending_grid',
              overlay: boostedTagFor(wall),
            ),
          );
        }, childCount: section.walls.length),
      ),
    );
  }
}
