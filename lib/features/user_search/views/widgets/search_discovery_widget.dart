import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SearchDiscoveryWidget extends StatelessWidget {
  const SearchDiscoveryWidget({super.key, required this.onSearch});

  final void Function(String query, WallpaperSource source) onSearch;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _TrendingSection(),
          const SizedBox(height: 24),
          _CategorySection(onSearch: onSearch),
          const SizedBox(height: 24),
          const _ColorSection(),
        ],
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
        const _SectionHeader(label: 'Trending Right Now', icon: Icons.local_fire_department_rounded),
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 120,
                height: 185,
                child: CachedNetworkImage(imageUrl: thumbUrl, fit: BoxFit.cover),
              ),
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
    _animation = (context.prismModeStyleForWindow(listen: false) == 'Dark'
            ? TweenSequence<Color?>([
                TweenSequenceItem(tween: ColorTween(begin: Colors.white10, end: const Color(0x22FFFFFF)), weight: 1),
                TweenSequenceItem(tween: ColorTween(begin: const Color(0x22FFFFFF), end: Colors.white10), weight: 1),
              ])
            : TweenSequence<Color?>([
                TweenSequenceItem(
                    tween: ColorTween(
                        begin: Colors.black.withValues(alpha: .1), end: Colors.black.withValues(alpha: .14)),
                    weight: 1),
                TweenSequenceItem(
                    tween: ColorTween(
                        begin: Colors.black.withValues(alpha: .14), end: Colors.black.withValues(alpha: .1)),
                    weight: 1),
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
    return SizedBox(
      height: 185,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => Container(
          width: 120,
          height: 185,
          decoration: BoxDecoration(
            color: _animation.value,
            borderRadius: BorderRadius.circular(16),
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text(
            'Could not load trending',
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
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
  const _CategorySection({required this.onSearch});
  final void Function(String query, WallpaperSource source) onSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(label: 'Browse by Category', icon: Icons.grid_view_rounded),
        const SizedBox(height: 12),
        SizedBox(
          height: 165,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: categoryDefinitions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final cat = categoryDefinitions[index];
              return GestureDetector(
                onTap: () => onSearch(cat.name, cat.source),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 120,
                    height: 165,
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
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
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
        const _SectionHeader(label: 'Search by Color', icon: Icons.palette_rounded),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: _presetColors.map((swatch) {
              final color = Color(int.parse('FF${swatch.hex}', radix: 16));
              return GestureDetector(
                onTap: () => context.router.push(ColorRoute(hexColor: swatch.hex)),
                child: SizedBox(
                  width: 52,
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        swatch.name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                            ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
