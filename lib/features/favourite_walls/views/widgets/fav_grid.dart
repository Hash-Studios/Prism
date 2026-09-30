import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/wallpaper_detail_entity.dart';
import 'package:Prism/global/svg_assets.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
        entity: WallpaperDetailEntityX.fromFavouriteWall(wall),
        analyticsSurface: AnalyticsSurfaceValue.favouriteWallpaperView,
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
        return RefreshIndicator(
          backgroundColor: Theme.of(context).primaryColor,
          key: refreshFavKey,
          onRefresh: refreshList,
          child: !loaded
              ? const LoadingCards()
              : walls.isEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: SvgPicture.string(
                        themedIllustration(context, dark: favouritesDark, light: favouritesLight),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height * 0.1,
                    ),
                  ],
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
                  child: PulsePlaceholder(
                    builder: (context, placeholderColor) => GridView.builder(
                      shrinkWrap: true,
                      cacheExtent: 50000,
                      padding: EdgeInsets.zero,
                      itemCount: walls.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: wallpaperGridColumns(MediaQuery.sizeOf(context).width),
                        childAspectRatio: 0.5,
                      ),
                      itemBuilder: (context, index) => Semantics(
                        button: true,
                        label: wallpaperSemanticLabel(_favouriteWallAuthor(walls[index])),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: placeholderColor,
                                image: DecorationImage(
                                  image: CachedNetworkImageProvider(walls[index].thumbnailUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                                highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                                onTap: () => _openWall(walls, index),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
