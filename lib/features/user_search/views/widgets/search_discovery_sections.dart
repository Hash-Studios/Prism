import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/categories/category_catalog.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/features/user_search/views/widgets/palette_swatch.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const EdgeInsets _sectionHeaderPadding = EdgeInsets.fromLTRB(
  PrismSpace.page,
  PrismSpace.xl,
  PrismSpace.page,
  PrismSpace.sm,
);

const double _trendingWidth = 120;
const double _trendingHeight = _trendingWidth * 2;
const double _categoryWidth = 140;
const double _categoryHeight = 190;

/// Decode height, in physical pixels, for a portrait card of [width] and twice that height.
int _decodeHeight(BuildContext context, double width) => (width * 2 * MediaQuery.devicePixelRatioOf(context)).round();

/// A horizontal row that starts at the page margin and scrolls off the right edge.
Widget _hRow({required double height, required int count, required IndexedWidgetBuilder builder}) {
  return SizedBox(
    height: height,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: PrismSpace.pageInsets,
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(width: PrismSpace.xs),
      itemBuilder: builder,
    ),
  );
}

/// "Trending now": the wallhaven top list as portrait tiles.
class TrendingSection extends StatelessWidget {
  const TrendingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchDiscoveryBloc, SearchDiscoveryState>(
      builder: (context, state) {
        final bool loaded = state.status == LoadStatus.success;
        if (loaded && state.trendingWalls.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PrismSectionHeader(title: context.l10n.accountTrendingNow, padding: _sectionHeaderPadding),
            if (state.status == LoadStatus.failure)
              GlintState(
                kind: GlintStateKind.error,
                title: context.l10n.accountCouldNotLoadTrending,
                actionLabel: context.l10n.accountTryAgain,
                onAction: () => context.read<SearchDiscoveryBloc>().add(const SearchDiscoveryEvent.refreshRequested()),
                glintSize: 64,
                padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page, vertical: PrismSpace.xs),
              )
            else if (loaded)
              _TrendingList(walls: state.trendingWalls)
            else
              PrismSkeleton(
                child: _hRow(
                  height: _trendingHeight,
                  count: 6,
                  builder: (_, _) =>
                      const PrismBone(width: _trendingWidth, height: _trendingHeight, radius: PrismRadius.sm),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TrendingList extends StatelessWidget {
  const _TrendingList({required this.walls});

  final List<WallhavenWallpaper> walls;

  @override
  Widget build(BuildContext context) {
    final List<WallhavenWallpaper> items = walls.take(10).toList(growable: false);
    return _hRow(
      height: _trendingHeight + favouriteFooterHeight,
      count: items.length,
      builder: (context, index) {
        final WallhavenWallpaper wall = items[index];
        final String heroTag = prismHeroTag(
          Scrollable.maybeOf(context) ?? context,
          index,
          'search-trending-${wall.id}',
        );
        return SizedBox(
          width: _trendingWidth,
          child: FavouriteWallpaperCard(
            item: WallhavenFeedItem(id: wall.id, wallpaper: wall),
            child: PrismWallTile(
              url: wall.thumbnailUrl,
              fallbackUrl: wall.core.fullUrl,
              memCacheHeight: _decodeHeight(context, _trendingWidth),
              heroTag: heroTag,
              semanticLabel: wallpaperSemanticLabel(wall.core.authorName, context.l10n),
              onTap: () {
                PrismHaptics.tap();
                context.router.push(
                  WallpaperDetailRoute(
                    entity: WallhavenFeedItem(id: wall.id, wallpaper: wall),
                    heroTag: heroTag,
                    analyticsSurface: AnalyticsSurfaceValue.searchWallpaperScreen,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// "Browse by category": one image card per category.
class CategorySection extends StatelessWidget {
  const CategorySection({super.key});

  @override
  Widget build(BuildContext context) {
    final List<CategoryDefinition> categories = CategoryCatalog.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PrismSectionHeader(title: context.l10n.accountBrowseByCategory, padding: _sectionHeaderPadding),
        _hRow(
          height: _categoryHeight,
          count: categories.length,
          builder: (context, index) {
            final String name = categories[index].name;
            return _CategoryCard(
              name: name,
              image: categories[index].imageUrl,
              fallbackImage: categories[index].secondaryImageUrl,
              onTap: () {
                PrismHaptics.tap();
                context.router.push(CollectionViewRoute(collectionName: 'category:${Uri.encodeComponent(name)}'));
              },
            );
          },
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.name, required this.image, required this.fallbackImage, required this.onTap});

  final String name;
  final String image;
  final String fallbackImage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(PrismRadius.md);
    return PressScale(
      scale: 0.97,
      child: Semantics(
        button: true,
        label: context.l10n.accountCategorySemanticLabel(name),
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: _categoryWidth,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                PrismImageTile(
                  url: image,
                  fallbackUrl: fallbackImage,
                  memCacheHeight: _decodeHeight(context, _categoryWidth),
                  borderRadius: radius,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
                  ),
                ),
                Positioned(
                  left: PrismSpace.sm,
                  right: PrismSpace.sm,
                  bottom: PrismSpace.sm,
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PrismTextStyles.rowTitle(context).copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Browse by colour": a row of round swatches. A tap runs a colour-only search.
class ColourSection extends StatelessWidget {
  const ColourSection({super.key, required this.onPressed});

  final void Function(PrismPaletteColor color) onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PrismSectionHeader(title: context.l10n.accountBrowseByColour, padding: _sectionHeaderPadding),
        _hRow(
          height: 48,
          count: prismPalette.length,
          builder: (context, index) {
            final PrismPaletteColor entry = prismPalette[index];
            return PaletteSwatch(color: entry, onTap: () => onPressed(entry));
          },
        ),
      ],
    );
  }
}
