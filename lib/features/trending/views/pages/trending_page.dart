import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/home/refreshable_glint_state.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/features/trending/domain/entities/trending_range.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The most active Prism wallpapers: "This week" and "All time".
@RoutePage()
class TrendingPage extends StatelessWidget implements AutoRouteWrapper {
  const TrendingPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) =>
      BlocProvider<TrendingBloc>(create: (_) => getIt<TrendingBloc>()..add(const TrendingEvent.started()), child: this);

  static String _label(TrendingRange range) => switch (range) {
    TrendingRange.week => 'This week',
    TrendingRange.allTime => 'All time',
  };

  Future<void> _refresh(BuildContext context) {
    final TrendingBloc bloc = context.read<TrendingBloc>();
    PrismHaptics.impact();
    final Future<TrendingState> settled = bloc.stream.firstWhere((state) => state.current.status != LoadStatus.loading);
    bloc.add(const TrendingEvent.refreshRequested());
    return settled;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PrismPage(
      title: 'Trending',
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xxs, PrismSpace.page, PrismSpace.sm),
            child: BlocBuilder<TrendingBloc, TrendingState>(
              buildWhen: (previous, current) => previous.range != current.range,
              builder: (context, state) => PrismSegmented<TrendingRange>(
                values: TrendingRange.values,
                selected: state.range,
                labelOf: _label,
                onChanged: (range) => context.read<TrendingBloc>().add(TrendingEvent.rangeSelected(range)),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<TrendingBloc, TrendingState>(
              builder: (context, state) {
                final TrendingSection section = state.current;
                if (section.walls.isEmpty) {
                  if (section.status == LoadStatus.initial || section.status == LoadStatus.loading) {
                    return const LoadingCards();
                  }
                  final bool failed = section.status == LoadStatus.failure;
                  return RefreshableGlintState(
                    kind: failed ? GlintStateKind.error : GlintStateKind.empty,
                    title: failed ? "Couldn't load trending wallpapers" : 'Nothing is trending yet',
                    body: failed ? 'Check your connection and try again.' : 'Check back soon.',
                    actionLabel: failed ? 'Try again' : null,
                    onAction: failed ? () => unawaited(_refresh(context)) : null,
                    onRefresh: () => _refresh(context),
                  );
                }
                return RefreshIndicator(
                  color: cs.primary,
                  backgroundColor: cs.surfaceContainerHigh,
                  onRefresh: () => _refresh(context),
                  child: _TrendingGrid(key: ValueKey<TrendingRange>(state.range), walls: section.walls),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingGrid extends StatelessWidget {
  const _TrendingGrid({super.key, required this.walls});

  final List<PrismWallpaper> walls;

  @override
  Widget build(BuildContext context) {
    final int crossAxisCount = wallpaperGridColumns(MediaQuery.sizeOf(context).width);
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: PrismWallGrid.padding.copyWith(top: PrismSpace.xxs, bottom: PrismSpace.bottomBarClearance),
      itemCount: walls.length,
      gridDelegate: PrismWallGrid.delegate(context, columns: crossAxisCount),
      itemBuilder: (context, index) {
        final PrismWallpaper wall = walls[index];
        return KeyedSubtree(
          key: ValueKey<String>(wall.id),
          child: WallpaperTile(
            item: PrismFeedItem(id: wall.id, wallpaper: wall),
            index: index,
            crossAxisCount: crossAxisCount,
            quickActions: true,
            sourceContext: 'trending_grid',
          ),
        );
      },
    );
  }
}
