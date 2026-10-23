import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/features/trending/views/widgets/boosted_tag.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Trending tab of the home feed as slivers: the wallpapers trending this week in the home grid.
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrendingBloc, TrendingState>(bloc: bloc, builder: _walls);
  }

  Widget _walls(BuildContext context, TrendingState state) {
    if (state.walls.isEmpty) {
      if (state.status == LoadStatus.initial || state.status == LoadStatus.loading) {
        return const SliverToBoxAdapter(child: LoadingCards(useFeedLayout: true));
      }
      final bool failed = state.status == LoadStatus.failure;
      return SliverToBoxAdapter(
        child: GlintState(
          kind: failed ? GlintStateKind.error : GlintStateKind.empty,
          title: failed ? context.l10n.wallpaperTrendingLoadError : context.l10n.wallpaperTrendingEmptyTitle,
          body: failed ? context.l10n.wallpaperCheckConnection : context.l10n.wallpaperCheckBackSoon,
          actionLabel: failed ? context.l10n.wallpaperTryAgain : null,
          onAction: failed ? () => bloc.add(const TrendingEvent.refreshRequested()) : null,
        ),
      );
    }
    return SliverPadding(
      padding: PrismFeedLayout.gridPadding,
      sliver: SliverGrid(
        gridDelegate: PrismWallGrid.delegate(
          context,
          footerHeight: favouriteFooterHeight,
          columns: crossAxisCount,
          spacing: PrismFeedLayout.gridSpacing,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final wall = state.walls[index];
          return KeyedSubtree(
            key: ValueKey<String>(wall.id),
            child: WallpaperTile(
              item: PrismFeedItem(id: wall.id, wallpaper: wall),
              index: index,
              crossAxisCount: crossAxisCount,
              memCacheHeight: tileMemCacheHeight,
              sourceContext: 'home_trending_grid',
              overlay: boostedTagFor(wall),
            ),
          );
        }, childCount: state.walls.length),
      ),
    );
  }
}
