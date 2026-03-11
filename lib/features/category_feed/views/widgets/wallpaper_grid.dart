import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/home/wallpapers/seeMoreButton.dart';
import 'package:Prism/core/widgets/premiumBanners/walls.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/category_feed_bloc_adapter.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/navigation/views/widgets/inherited_scroll_controller_provider.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WallpaperGrid extends StatefulWidget {
  const WallpaperGrid({super.key});

  @override
  State<WallpaperGrid> createState() => _WallpaperGridState();
}

class _WallpaperGridState extends State<WallpaperGrid> {
  final GlobalKey<RefreshIndicatorState> refreshHomeKey = GlobalKey<RefreshIndicatorState>();
  final ScrollMilestoneTracker _scrollMilestoneTracker = ScrollMilestoneTracker();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();

  bool seeMoreLoader = false;
  int _lastLoggedSubWallsCount = -1;

  @override
  void initState() {
    super.initState();
    _contentLoadTracker.start();
  }

  Future<void> refreshList() async {
    refreshHomeKey.currentState?.show();
    _contentLoadTracker.start();
    _scrollMilestoneTracker.reset();
    await context.categoryChangeWallpaperFuture(context.categorySelectedChoice(listen: false), "r");
  }

  Future<void> _triggerSeeMore({required bool hasMore, required int currentItemCount}) async {
    if (seeMoreLoader || !hasMore) {
      return;
    }
    setState(() {
      seeMoreLoader = true;
    });
    logger.d("[WallpaperGrid] see more triggered", fields: <String, Object?>{"currentItems": currentItemCount});
    try {
      await context.categoryChangeWallpaperFuture(context.categorySelectedChoice(listen: false), "s");
    } finally {
      if (mounted) {
        setState(() {
          seeMoreLoader = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController? controller = InheritedDataProvider.of(context)?.scrollController;
    final CategoryFeedState state = context.watch<CategoryFeedBloc>().state;
    final List<PrismFeedItem> subWalls = state.items.whereType<PrismFeedItem>().toList(growable: false);

    if (_lastLoggedSubWallsCount != subWalls.length) {
      _lastLoggedSubWallsCount = subWalls.length;
      logger.d("[WallpaperGrid] build", fields: <String, Object?>{"items": subWalls.length, "hasMore": state.hasMore});
    }
    if (subWalls.isNotEmpty) {
      _contentLoadTracker.success(
        itemCount: subWalls.length,
        onSuccess: ({required int loadTimeMs, int? itemCount}) async {
          await analytics.track(
            SurfaceContentLoadedEvent(
              surface: AnalyticsSurfaceValue.homeWallpaperGrid,
              result: EventResultValue.success,
              loadTimeMs: loadTimeMs,
              sourceContext: 'home_wallpaper_grid_initial',
              itemCount: itemCount,
            ),
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 5.0),
      child: RefreshIndicator(
        backgroundColor: Theme.of(context).primaryColor,
        key: refreshHomeKey,
        onRefresh: refreshList,
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            _scrollMilestoneTracker.onScroll(
              metrics: scrollInfo.metrics,
              itemCount: subWalls.length,
              onMilestoneReached: (depth, {required int itemCount}) async {
                await analytics.track(
                  ScrollMilestoneReachedEvent(
                    surface: AnalyticsSurfaceValue.homeWallpaperGrid,
                    listName: ScrollListNameValue.wallpaperGrid,
                    depth: depth,
                    sourceContext: 'home_wallpaper_grid_scroll',
                    itemCount: itemCount,
                  ),
                );
              },
            );
            if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
              unawaited(_triggerSeeMore(hasMore: state.hasMore, currentItemCount: subWalls.length));
            }
            return false;
          },
          child: GridView.builder(
            controller: controller,
            physics: const ScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(5, 0, 5, 4),
            itemCount: subWalls.isEmpty ? 20 : subWalls.length,
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
              childAspectRatio: 0.6625,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              if (subWalls.isEmpty) {
                return Container(
                  decoration: BoxDecoration(
                    color: context.prismModeStyleForContext() == "Dark"
                        ? Colors.white10
                        : Colors.black.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }
              final int itemIndex = index;
              if (itemIndex == subWalls.length - 1) {
                return SeeMoreButton(
                  seeMoreLoader: seeMoreLoader,
                  func: () {
                    unawaited(
                      analytics.track(
                        const SurfaceActionTappedEvent(
                          surface: AnalyticsSurfaceValue.homeWallpaperGrid,
                          action: AnalyticsActionValue.seeMoreTapped,
                          sourceContext: 'home_wallpaper_grid_see_more',
                        ),
                      ),
                    );
                    unawaited(_triggerSeeMore(hasMore: state.hasMore, currentItemCount: subWalls.length));
                  },
                );
              }
              final PrismFeedItem item = subWalls[itemIndex];
              return PremiumBannerWalls(
                comparator: !app_state.isPremiumWall(
                  app_state.premiumCollections,
                  item.wallpaper.collections ?? const <String>[],
                ),
                defaultChild: WallpaperTile(item: item, index: itemIndex),
                trueChild: WallpaperTile(item: item, index: itemIndex),
              );
            },
          ),
        ),
      ),
    );
  }
}
