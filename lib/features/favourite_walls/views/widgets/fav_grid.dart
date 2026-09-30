import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

String? _favouriteWallAuthor(FavouriteWallEntity wall) => switch (wall) {
  PrismFavouriteWall(:final wallpaper) => wallpaper.core.authorName,
  WallhavenFavouriteWall(:final wallpaper) => wallpaper.core.authorName,
  PexelsFavouriteWall(:final wallpaper) => wallpaper.core.authorName,
  LegacyFavouriteWall(:final legacyPayload) => legacyPayload['photographer']?.toString(),
};

class FavouriteGrid extends StatefulWidget {
  const FavouriteGrid({super.key});

  @override
  State<FavouriteGrid> createState() => _FavouriteGridState();
}

class _FavouriteGridState extends State<FavouriteGrid> {
  final GlobalKey<RefreshIndicatorState> refreshFavKey = GlobalKey<RefreshIndicatorState>();
  final ScrollMilestoneTracker _scrollMilestoneTracker = ScrollMilestoneTracker();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();

  @override
  void initState() {
    super.initState();
    _contentLoadTracker.start();
    unawaited(context.favouriteWallsAdapter(listen: false).getDataBase());
  }

  Future<void> refreshList() async {
    refreshFavKey.currentState?.show();
    _contentLoadTracker.start();
    _scrollMilestoneTracker.reset();
    await context.favouriteWallsAdapter(listen: false).getDataBase(forceRefresh: true);
  }

  void _openWall(List<FavouriteWallEntity> walls, int index) {
    final FavouriteWallEntity wall = walls[index];
    if (wall is LegacyFavouriteWall) {
      toasts.error("This wallpaper can't be opened.");
      return;
    }
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.favouriteWallsGrid,
          action: AnalyticsActionValue.tileOpened,
          sourceContext: 'favourite_walls_grid_tile',
          itemType: ItemTypeValue.wallpaper,
          itemId: wall.id,
          index: index,
        ),
      ),
    );
    context.router.push(
      WallpaperDetailRoute(
        entity: wall.toFeedItem(),
        analyticsSurface: AnalyticsSurfaceValue.favouriteWallpaperView,
        heroTag: prismHeroTag(this, index, wall.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavouriteWallsBloc, FavouriteWallsState>(
      builder: (context, state) {
        final List<FavouriteWallEntity> walls = state.items;
        final bool loaded =
            state.status != LoadStatus.initial && (state.status != LoadStatus.loading || walls.isNotEmpty);
        if (loaded) {
          _contentLoadTracker.success(
            itemCount: walls.length,
            onSuccess: ({required int loadTimeMs, int? itemCount}) async {
              await analytics.track(
                SurfaceContentLoadedEvent(
                  surface: AnalyticsSurfaceValue.favouriteWallsGrid,
                  result: (itemCount ?? 0) > 0 ? EventResultValue.success : EventResultValue.empty,
                  loadTimeMs: loadTimeMs,
                  sourceContext: 'favourite_walls_grid_initial',
                  itemCount: itemCount,
                ),
              );
            },
          );
        }
        final ColorScheme cs = Theme.of(context).colorScheme;
        return RefreshIndicator(
          color: cs.primary,
          backgroundColor: cs.surfaceContainerHigh,
          key: refreshFavKey,
          onRefresh: refreshList,
          child: !loaded
              ? const LoadingCards()
              : walls.isEmpty
              ? _PullableState(
                  child: state.status == LoadStatus.failure
                      ? GlintState(
                          kind: GlintStateKind.error,
                          title: "Couldn't load your favourites",
                          body: 'Check your connection and try again.',
                          actionLabel: 'Try again',
                          onAction: () => unawaited(refreshList()),
                        )
                      : GlintState(
                          kind: GlintStateKind.empty,
                          title: 'No favourites yet',
                          body: 'Tap the heart on a wallpaper to keep it here.',
                          actionLabel: 'Browse wallpapers',
                          onAction: () =>
                              context.router.navigate(const DashboardRoute(children: <PageRouteInfo>[HomeTabRoute()])),
                        ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    _scrollMilestoneTracker.onScroll(
                      metrics: notification.metrics,
                      itemCount: walls.length,
                      onMilestoneReached: (depth, {required int itemCount}) async {
                        await analytics.track(
                          ScrollMilestoneReachedEvent(
                            surface: AnalyticsSurfaceValue.favouriteWallsGrid,
                            listName: ScrollListNameValue.favouriteWallsGrid,
                            depth: depth,
                            sourceContext: 'favourite_walls_grid_scroll',
                            itemCount: itemCount,
                          ),
                        );
                      },
                    );
                    return false;
                  },
                  child: GridView.builder(
                    padding: PrismWallGrid.padding.copyWith(
                      top: PrismSpace.xxs,
                      bottom: MediaQuery.paddingOf(context).bottom + PrismSpace.md,
                    ),
                    itemCount: walls.length,
                    gridDelegate: PrismWallGrid.delegate(context),
                    itemBuilder: (context, index) => PrismWallTile(
                      url: walls[index].thumbnailUrl,
                      heroTag: prismHeroTag(this, index, walls[index].id),
                      semanticLabel: wallpaperSemanticLabel(_favouriteWallAuthor(walls[index])),
                      onTap: () => _openWall(walls, index),
                      overlay: walls[index] is LegacyFavouriteWall
                          ? IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: 0.4)))
                          : null,
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// Lets a short state scroll, so pull to refresh still works on it.
class _PullableState extends StatelessWidget {
  const _PullableState({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}
