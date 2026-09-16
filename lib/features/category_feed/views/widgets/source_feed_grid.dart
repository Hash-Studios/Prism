import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/widgets/home/wallpapers/seeMoreButton.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/category_feed_bloc_adapter.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shared grid body for a single [FeedItemEntity] subtype, extracted from the
/// near-identical `WallHavenGrid` and `PexelsGrid` widgets. Only the item
/// subtype `T` and the analytics constants below differ between sources.
class SourceFeedGrid<T extends FeedItemEntity> extends StatefulWidget {
  const SourceFeedGrid({super.key, required this.surface, required this.listName, required this.sourceContextPrefix});

  final AnalyticsSurfaceValue surface;
  final ScrollListNameValue listName;
  final String sourceContextPrefix;

  @override
  State<SourceFeedGrid<T>> createState() => _SourceFeedGridState<T>();
}

class _SourceFeedGridState<T extends FeedItemEntity> extends State<SourceFeedGrid<T>> {
  final GlobalKey<RefreshIndicatorState> refreshHomeKey = GlobalKey<RefreshIndicatorState>();
  final ScrollMilestoneTracker _scrollMilestoneTracker = ScrollMilestoneTracker();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();
  bool seeMoreLoader = false;

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

  Future<void> _triggerSeeMore({required bool hasMore, required int itemCount}) async {
    if (seeMoreLoader || !hasMore) {
      return;
    }
    setState(() {
      seeMoreLoader = true;
    });
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
    final CategoryFeedState state = context.watch<CategoryFeedBloc>().state;
    final List<T> walls = state.items.whereType<T>().toList(growable: false);

    if (walls.isNotEmpty) {
      _contentLoadTracker.success(
        itemCount: walls.length,
        onSuccess: ({required int loadTimeMs, int? itemCount}) async {
          await analytics.track(
            SurfaceContentLoadedEvent(
              surface: widget.surface,
              result: EventResultValue.success,
              loadTimeMs: loadTimeMs,
              sourceContext: '${widget.sourceContextPrefix}_initial',
              itemCount: itemCount,
            ),
          );
        },
      );
    }

    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
      key: refreshHomeKey,
      onRefresh: refreshList,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          _scrollMilestoneTracker.onScroll(
            metrics: scrollInfo.metrics,
            itemCount: walls.length,
            onMilestoneReached: (depth, {required int itemCount}) async {
              await analytics.track(
                ScrollMilestoneReachedEvent(
                  surface: widget.surface,
                  listName: widget.listName,
                  depth: depth,
                  sourceContext: '${widget.sourceContextPrefix}_scroll',
                  itemCount: itemCount,
                ),
              );
            },
          );
          if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            unawaited(_triggerSeeMore(hasMore: state.hasMore, itemCount: walls.length));
          }
          return false;
        },
        child: GridView.builder(
          padding: EdgeInsets.zero,
          itemCount: walls.isEmpty ? 20 : walls.length,
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).orientation == Orientation.portrait ? 3 : 5,
            childAspectRatio: 0.5,
          ),
          itemBuilder: (context, index) {
            if (walls.isEmpty) {
              return Container(
                decoration: BoxDecoration(
                  color: context.prismModeStyleForContext() == "Dark"
                      ? Colors.white10
                      : Colors.black.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                ),
              );
            }
            if (index == walls.length - 1) {
              return SeeMoreButton(
                seeMoreLoader: seeMoreLoader,
                func: () {
                  unawaited(
                    analytics.track(
                      SurfaceActionTappedEvent(
                        surface: widget.surface,
                        action: AnalyticsActionValue.seeMoreTapped,
                        sourceContext: '${widget.sourceContextPrefix}_see_more',
                      ),
                    ),
                  );
                  unawaited(_triggerSeeMore(hasMore: state.hasMore, itemCount: walls.length));
                },
              );
            }
            return WallpaperTile(item: walls[index], index: index);
          },
        ),
      ),
    );
  }
}
