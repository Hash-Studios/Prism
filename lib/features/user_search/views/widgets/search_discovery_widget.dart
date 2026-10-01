import 'dart:math';

import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Portrait card width: 3.5 cards across a phone, capped so a tablet does not get giant cards.
double _cardWidth(BuildContext context) => min(MediaQuery.sizeOf(context).width / 3.5, 160);

class SearchDiscoveryWidget extends StatelessWidget {
  const SearchDiscoveryWidget({super.key, required this.tags, required this.selectedTag, required this.onTagPressed});

  final List<String> tags;
  final String selectedTag;
  final void Function(String tag) onTagPressed;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _TagsRow(tags: tags, selectedTag: selectedTag, onTagPressed: onTagPressed),
          const SizedBox(height: 8),
          const _FindCreatorsRow(),
          const SizedBox(height: 12),
          _TrendingSection(),
          const SizedBox(height: 16),
          const _CategorySection(),
          const SizedBox(height: 16),
          const _ColorSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _TagsRow extends StatelessWidget {
  const _TagsRow({required this.tags, required this.selectedTag, required this.onTagPressed});

  final List<String> tags;
  final String selectedTag;
  final void Function(String tag) onTagPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: tags.length,
        itemBuilder: (context, index) {
          final tag = tags[index];
          final isSelected = selectedTag.toLowerCase() == tag.toLowerCase();
          return ActionChip(
            pressElevation: 5,
            side: BorderSide.none,
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
            backgroundColor: Colors.transparent,
            label: Text(
              "#$tag",
              style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                fontFamily: 'Satoshi',
                fontSize: 12,
                color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.secondary,
              ),
            ),
            onPressed: () {
              PrismHaptics.selection();
              onTagPressed(tag);
            },
          );
        },
      ),
    );
  }
}

class _FindCreatorsRow extends StatelessWidget {
  const _FindCreatorsRow();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () {
          PrismHaptics.tap();
          context.router.push(const UserSearchRoute());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(JamIcons.user_circle, size: 18, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find Creators',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    Text(
                      'Search Prism users by name',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendingSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(label: 'Trending Right Now', icon: JamIcons.flame_f),
        const SizedBox(height: 12),
        BlocBuilder<SearchDiscoveryBloc, SearchDiscoveryState>(
          builder: (context, state) {
            if (state.status == LoadStatus.failure) {
              return _TrendingError(
                onRetry: () => context.read<SearchDiscoveryBloc>().add(const SearchDiscoveryEvent.refreshRequested()),
              );
            }
            if (state.status == LoadStatus.success && state.trendingWalls.isNotEmpty) {
              return _TrendingList(walls: state.trendingWalls);
            }
            // initial or loading
            return const _TrendingSkeletonRow();
          },
        ),
      ],
    );
  }
}

class _TrendingList extends StatelessWidget {
  const _TrendingList({required this.walls});
  final List<WallhavenWallpaper> walls;

  @override
  Widget build(BuildContext context) {
    final items = walls.take(10).toList(growable: false);
    return SizedBox(
      height: 185,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final wall = items[index];
          final thumbUrl = wall.thumbnailUrl;
          return Semantics(
            button: true,
            label: wallpaperSemanticLabel(wall.core.authorName),
            child: GestureDetector(
              onTap: () {
                PrismHaptics.tap();
                context.router.push(
                  WallpaperDetailRoute(
                    entity: WallhavenFeedItem(id: wall.id, wallpaper: wall),
                    analyticsSurface: AnalyticsSurfaceValue.searchWallpaperScreen,
                  ),
                );
              },
              child: SizedBox(
                width: _cardWidth(context),
                height: _cardWidth(context) * 2,
                child: CachedNetworkImage(imageUrl: thumbUrl, fit: BoxFit.cover),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrendingSkeletonRow extends StatelessWidget {
  const _TrendingSkeletonRow();

  @override
  Widget build(BuildContext context) {
    final itemWidth = _cardWidth(context);
    final itemHeight = itemWidth * 2;
    return SizedBox(
      height: itemHeight,
      child: PulsePlaceholder(
        builder: (context, _) => ListView.builder(
          padding: EdgeInsets.zero,
          scrollDirection: Axis.horizontal,
          itemCount: 6,
          itemBuilder: (_, _) => SizedBox(width: itemWidth, height: itemHeight, child: const PulseFill()),
        ),
      ),
    );
  }
}

class _TrendingError extends StatelessWidget {
  const _TrendingError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlintState(
      kind: GlintStateKind.error,
      title: 'Could not load trending',
      actionLabel: 'Retry',
      onAction: onRetry,
      glintSize: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(label: 'Browse by Category', icon: JamIcons.grid_f),
        const SizedBox(height: 12),
        SizedBox(
          height: _cardWidth(context) * 2,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            scrollDirection: Axis.horizontal,
            itemCount: categoryDefinitions.length,
            itemBuilder: (context, index) {
              final cat = categoryDefinitions[index];
              return Semantics(
                button: true,
                child: GestureDetector(
                  onTap: () {
                    PrismHaptics.tap();
                    context.router.push(
                      CollectionViewRoute(collectionName: 'category:${Uri.encodeComponent(cat.name)}'),
                    );
                  },
                  child: SizedBox(
                    width: _cardWidth(context),
                    height: _cardWidth(context) * 2,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(imageUrl: cat.imageUrl, fit: BoxFit.cover),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 10,
                          child: Text(
                            cat.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Satoshi',
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ColorSwatch {
  const _ColorSwatch({required this.name, required this.color});
  final String name;
  final Color color;
}

const List<_ColorSwatch> _presetColors = [
  _ColorSwatch(name: 'Red', color: Color(0xFFb71c1c)),
  _ColorSwatch(name: 'Blue', color: Color(0xFF1565c0)),
  _ColorSwatch(name: 'Green', color: Color(0xFF2e7d32)),
  _ColorSwatch(name: 'Purple', color: Color(0xFF6a1b9a)),
  _ColorSwatch(name: 'Orange', color: Color(0xFFe65100)),
  _ColorSwatch(name: 'Yellow', color: Color(0xFFf9a825)),
  _ColorSwatch(name: 'Pink', color: Color(0xFFad1457)),
  _ColorSwatch(name: 'Teal', color: Color(0xFF00695c)),
  _ColorSwatch(name: 'White', color: Color(0xFFf5f5f5)),
  _ColorSwatch(name: 'Black', color: Color(0xFF212121)),
  _ColorSwatch(name: 'Brown', color: Color(0xFF4e342e)),
  _ColorSwatch(name: 'Cyan', color: Color(0xFF00838f)),
];

class _ColorSection extends StatelessWidget {
  const _ColorSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(label: 'Search by Color', icon: JamIcons.brush_f),
        const SizedBox(height: 12),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 120),
          itemCount: _presetColors.length,
          itemBuilder: (context, index) {
            final swatch = _presetColors[index];
            return Semantics(
              button: true,
              label: swatch.name,
              child: GestureDetector(
                onTap: () {
                  PrismHaptics.tap();
                  context.router.push(ColorRoute(hexColor: swatch.color.rgbHex));
                },
                child: Container(decoration: BoxDecoration(color: swatch.color)),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 12,
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
