import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

class WallpaperRecommendations extends StatelessWidget {
  const WallpaperRecommendations({
    super.key,
    required this.state,
    required this.heroScope,
    required this.onOpen,
    required this.onLoadMore,
  });

  final RecommendationState state;
  final Object heroScope;
  final void Function(FeedItemEntity, String) onOpen;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.status == RecommendationStatus.exhausted && state.items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(PrismSpace.md, PrismSpace.lg, PrismSpace.md, PrismSpace.sm),
          sliver: SliverToBoxAdapter(
            child: Text(switch (state.kind) {
              RecommendationKind.related => context.l10n.wallpaperMoreLikeThis,
              RecommendationKind.discovery => context.l10n.wallpaperFeedDiscovery,
              RecommendationKind.offline => context.l10n.wallpaperOffline,
            }, style: PrismTextStyles.cardTitle(context)),
          ),
        ),
        // Tile-shaped placeholders hold the grid's place until the first page arrives.
        if (state.items.isEmpty && (state.loading || !state.started))
          SliverPadding(
            padding: PrismWallGrid.padding,
            sliver: PulsePlaceholder(
              builder: (context, _) => SliverGrid(
                gridDelegate: PrismWallGrid.delegate(context, footerHeight: favouriteFooterHeight),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const PulseFill(borderRadius: PrismWallGrid.tileRadius),
                  childCount: wallpaperGridColumns(MediaQuery.sizeOf(context).width) * 2,
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: PrismWallGrid.padding,
          sliver: SliverGrid(
            gridDelegate: PrismWallGrid.delegate(context, footerHeight: favouriteFooterHeight),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = state.items[index];
              final hero = prismHeroTag(heroScope, index, '${item.source.name}:${item.id}');
              return FavouriteWallpaperCard(
                key: ValueKey((item.source, item.id)),
                item: item,
                child: PrismWallTile(
                  url: item.thumbnailUrl,
                  fallbackUrl: item.source == WallpaperSource.prism ? null : item.fullUrl,
                  heroTag: hero,
                  semanticLabel: item.semanticLabel(context.l10n),
                  onTap: () => onOpen(item, hero),
                  memCacheHeight: gridTileDecodeHeight(
                    context,
                    crossAxisCount: wallpaperGridColumns(MediaQuery.sizeOf(context).width),
                  ),
                ),
              );
            }, childCount: state.items.length),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: state.items.isEmpty && (state.loading || !state.started)
                  ? const SizedBox.shrink()
                  : state.loading || !state.started
                  ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : state.failed
                  ? TextButton.icon(
                      onPressed: onLoadMore,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.l10n.wallpaperFeedLoadMoreError),
                    )
                  : state.hasMore
                  ? TextButton(onPressed: onLoadMore, child: Text(context.l10n.economyShowMore))
                  : Text(context.l10n.wallpaperFeedCaughtUpTitle, style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
        ),
      ],
    );
  }
}
