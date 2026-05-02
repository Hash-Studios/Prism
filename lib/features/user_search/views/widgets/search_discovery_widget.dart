import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
            onPressed: () => onTagPressed(tag),
          );
        },
      ),
    );
  }
}

// ─── Find Creators Row ───────────────────────────────────────────────────────

class _FindCreatorsRow extends StatelessWidget {
  const _FindCreatorsRow();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.router.push(const UserSearchRoute()),
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
            Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ─── Trending Section ───────────────────────────────────────────────────────

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
    final items = walls.length > 10 ? walls.sublist(0, 10) : walls;
    return SizedBox(
      height: 185,
      child: ListView.separated(
        padding: const EdgeInsets.all(0),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox.shrink(),
        itemBuilder: (context, index) {
          final wall = items[index];
          final thumbUrl = wall.thumbs?['original'] ?? wall.core.thumbnailUrl;
          return GestureDetector(
            onTap: () {
              context.router.push(
                WallpaperDetailRoute(
                  entity: WallhavenDetailEntity(wallpaper: wall),
                  analyticsSurface: AnalyticsSurfaceValue.searchWallpaperScreen,
                ),
              );
            },
            child: SizedBox(
              width: (MediaQuery.of(context).size.width) / 3.5,
              height: (MediaQuery.of(context).size.width) / 3.5 * 2,
              child: CachedNetworkImage(imageUrl: thumbUrl, fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }
}

class _TrendingSkeletonRow extends StatefulWidget {
  const _TrendingSkeletonRow();

  @override
  State<_TrendingSkeletonRow> createState() => _TrendingSkeletonRowState();
}

class _TrendingSkeletonRowState extends State<_TrendingSkeletonRow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _animation =
        (context.prismModeStyleForWindow(listen: false) == 'Dark'
                ? TweenSequence<Color?>([
                    TweenSequenceItem(
                      tween: ColorTween(begin: Colors.white10, end: const Color(0x22FFFFFF)),
                      weight: 1,
                    ),
                    TweenSequenceItem(
                      tween: ColorTween(begin: const Color(0x22FFFFFF), end: Colors.white10),
                      weight: 1,
                    ),
                  ])
                : TweenSequence<Color?>([
                    TweenSequenceItem(
                      tween: ColorTween(
                        begin: Colors.black.withValues(alpha: .1),
                        end: Colors.black.withValues(alpha: .14),
                      ),
                      weight: 1,
                    ),
                    TweenSequenceItem(
                      tween: ColorTween(
                        begin: Colors.black.withValues(alpha: .14),
                        end: Colors.black.withValues(alpha: .1),
                      ),
                      weight: 1,
                    ),
                  ]))
            .animate(_controller)
          ..addListener(() => setState(() {}));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemWidth = MediaQuery.of(context).size.width / 3.5;
    final itemHeight = itemWidth * 2;
    return SizedBox(
      height: itemHeight,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox.shrink(),
        itemBuilder: (_, __) => Container(width: itemWidth, height: itemHeight, color: _animation.value),
      ),
    );
  }
}

class _TrendingError extends StatelessWidget {
  const _TrendingError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text(
            'Could not load trending',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontFamily: 'Satoshi',
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ─── Category Section ────────────────────────────────────────────────────────

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
          height: MediaQuery.of(context).size.width / 3.5 * 2,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            scrollDirection: Axis.horizontal,
            itemCount: categoryDefinitions.length,
            separatorBuilder: (_, __) => const SizedBox.shrink(),
            itemBuilder: (context, index) {
              final cat = categoryDefinitions[index];
              return GestureDetector(
                onTap: () {
                  context.router.push(CollectionViewRoute(collectionName: 'category:${Uri.encodeComponent(cat.name)}'));
                },
                child: SizedBox(
                  width: MediaQuery.of(context).size.width / 3.5,
                  height: MediaQuery.of(context).size.width / 3.5 * 2,
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
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Color Section ───────────────────────────────────────────────────────────

class _ColorSwatch {
  const _ColorSwatch({required this.name, required this.hex});
  final String name;
  final String hex;
}

const List<_ColorSwatch> _presetColors = [
  _ColorSwatch(name: 'Red', hex: 'b71c1c'),
  _ColorSwatch(name: 'Blue', hex: '1565c0'),
  _ColorSwatch(name: 'Green', hex: '2e7d32'),
  _ColorSwatch(name: 'Purple', hex: '6a1b9a'),
  _ColorSwatch(name: 'Orange', hex: 'e65100'),
  _ColorSwatch(name: 'Yellow', hex: 'f9a825'),
  _ColorSwatch(name: 'Pink', hex: 'ad1457'),
  _ColorSwatch(name: 'Teal', hex: '00695c'),
  _ColorSwatch(name: 'White', hex: 'f5f5f5'),
  _ColorSwatch(name: 'Black', hex: '212121'),
  _ColorSwatch(name: 'Brown', hex: '4e342e'),
  _ColorSwatch(name: 'Cyan', hex: '00838f'),
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
          padding: const EdgeInsets.all(0),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
          itemCount: _presetColors.length,
          itemBuilder: (context, index) {
            final swatch = _presetColors[index];
            final color = Color(int.parse('FF${swatch.hex}', radix: 16));
            return GestureDetector(
              onTap: () => context.router.push(ColorRoute(hexColor: swatch.hex)),
              child: Container(decoration: BoxDecoration(color: color)),
            );
          },
        ),
      ],
    );
  }
}

// ─── Shared Section Header ───────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 6),
          ],
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
