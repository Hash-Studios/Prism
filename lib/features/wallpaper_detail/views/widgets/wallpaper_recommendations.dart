import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/wallpaper/placeholder_color.dart';
import 'package:Prism/core/wallpaper/wallpaper_display_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/core/widgets/prism_loader.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_feed.dart';
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
  final void Function(FeedItemEntity item, String heroTag, WallpaperFeed feed) onOpen;
  final VoidCallback onLoadMore;

  String _heroTag(int index, FeedItemEntity item) => prismHeroTag(heroScope, index, '${item.source.name}:${item.id}');

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
                  childCount: PrismWallGrid.columns(context) * 2,
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
              final hero = _heroTag(index, item);
              return FavouriteWallpaperCard(
                key: ValueKey((item.source, item.id)),
                item: item,
                child: PrismWallTile(
                  url: item.thumbnailUrl,
                  fallbackUrl: item.source == WallpaperSource.prism ? null : item.fullUrl,
                  cachedFullUrl: WallpaperDisplaySource.of(item).full,
                  heroTag: hero,
                  placeholderColor: placeholderColorOf(item, Theme.of(context).scaffoldBackgroundColor),
                  semanticLabel: item.semanticLabel(context.l10n),
                  onTap: () {
                    PrismHaptics.tap();
                    onOpen(
                      item,
                      hero,
                      WallpaperFeed(
                        grid: context,
                        tiles: [
                          for (final (i, wall) in state.items.indexed)
                            (item: wall, index: i, heroTag: _heroTag(i, wall)),
                        ],
                      ),
                    );
                  },
                  memCacheHeight: gridTileDecodeHeight(context, crossAxisCount: PrismWallGrid.columns(context)),
                ),
              );
            }, childCount: state.items.length),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(PrismSpace.xl),
            child: Center(
              child: state.items.isEmpty && (state.loading || !state.started)
                  ? const SizedBox.shrink()
                  : state.loading || !state.started
                  ? const PrismLoader()
                  : state.failed
                  ? PrismButton(
                      label: context.l10n.wallpaperFeedLoadMoreError,
                      icon: Icons.refresh_rounded,
                      variant: PrismButtonVariant.ghost,
                      size: PrismButtonSize.compact,
                      maxLines: 2,
                      onPressed: onLoadMore,
                    )
                  : state.hasMore
                  ? PrismButton(
                      label: context.l10n.economyShowMore,
                      variant: PrismButtonVariant.ghost,
                      size: PrismButtonSize.compact,
                      onPressed: onLoadMore,
                    )
                  : Text(context.l10n.wallpaperFeedCaughtUpTitle, style: PrismTextStyles.caption(context)),
            ),
          ),
        ),
      ],
    );
  }
}
