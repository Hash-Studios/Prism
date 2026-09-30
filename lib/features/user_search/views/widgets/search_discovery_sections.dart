import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
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
            const PrismSectionHeader(title: 'Trending now', padding: _sectionHeaderPadding),
            if (state.status == LoadStatus.failure)
              GlintState(
                kind: GlintStateKind.error,
                title: "Couldn't load trending",
                actionLabel: 'Try again',
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
      height: _trendingHeight,
      count: items.length,
      builder: (context, index) {
        final WallhavenWallpaper wall = items[index];
        return SizedBox(
          width: _trendingWidth,
          child: PrismWallTile(
            url: wall.thumbnailUrl,
            semanticLabel: wallpaperSemanticLabel(wall.core.authorName),
            onTap: () => context.router.push(
              WallpaperDetailRoute(
                entity: WallhavenFeedItem(id: wall.id, wallpaper: wall),
                analyticsSurface: AnalyticsSurfaceValue.searchWallpaperScreen,
              ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const PrismSectionHeader(title: 'Browse by category', padding: _sectionHeaderPadding),
        _hRow(
          height: _categoryHeight,
          count: categoryDefinitions.length,
          builder: (context, index) {
            final String name = categoryDefinitions[index].name;
            return _CategoryCard(
              name: name,
              image: categoryDefinitions[index].imageUrl,
              onTap: () =>
                  context.router.push(CollectionViewRoute(collectionName: 'category:${Uri.encodeComponent(name)}')),
            );
          },
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.name, required this.image, required this.onTap});

  final String name;
  final String image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(PrismRadius.md);
    return PressScale(
      scale: 0.97,
      child: Semantics(
        button: true,
        label: 'Category, $name',
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
                PrismImageTile(url: image, borderRadius: radius),
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

class _ColourSwatch {
  const _ColourSwatch(this.name, this.color);

  final String name;
  final Color color;
}

const List<_ColourSwatch> _presetColours = <_ColourSwatch>[
  _ColourSwatch('Red', Color(0xFFb71c1c)),
  _ColourSwatch('Blue', Color(0xFF1565c0)),
  _ColourSwatch('Green', Color(0xFF2e7d32)),
  _ColourSwatch('Purple', Color(0xFF6a1b9a)),
  _ColourSwatch('Orange', Color(0xFFe65100)),
  _ColourSwatch('Yellow', Color(0xFFf9a825)),
  _ColourSwatch('Pink', Color(0xFFad1457)),
  _ColourSwatch('Teal', Color(0xFF00695c)),
  _ColourSwatch('White', Color(0xFFf5f5f5)),
  _ColourSwatch('Black', Color(0xFF212121)),
  _ColourSwatch('Brown', Color(0xFF4e342e)),
  _ColourSwatch('Cyan', Color(0xFF00838f)),
];

/// "Search by colour": rounded swatches, four to a row.
class ColourSection extends StatelessWidget {
  const ColourSection({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const PrismSectionHeader(title: 'Search by colour', padding: _sectionHeaderPadding),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: PrismSpace.xs,
          crossAxisSpacing: PrismSpace.xs,
          padding: PrismSpace.pageInsets,
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          children: <Widget>[
            for (final _ColourSwatch swatch in _presetColours)
              PressScale(
                scale: 0.94,
                child: Semantics(
                  button: true,
                  label: '${swatch.name} wallpapers',
                  excludeSemantics: true,
                  onTap: () => context.router.push(ColorRoute(hexColor: swatch.color.rgbHex)),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.router.push(ColorRoute(hexColor: swatch.color.rgbHex)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: swatch.color,
                        borderRadius: BorderRadius.circular(PrismRadius.sm),
                        border: Border.all(color: cs.onSurface.withValues(alpha: 0.12)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
