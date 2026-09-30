import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shared grid body for a single [FeedItemEntity] subtype. Only the item
/// subtype `T` and the analytics constants below differ between sources.
class SourceFeedGrid<T extends FeedItemEntity> extends StatefulWidget {
  const SourceFeedGrid({
    super.key,
    required this.surface,
    required this.listName,
    required this.sourceContextPrefix,
    this.physics,
    this.itemWrapper,
  });

  final AnalyticsSurfaceValue surface;
  final ScrollListNameValue listName;
  final String sourceContextPrefix;
  final ScrollPhysics? physics;
  final Widget Function(BuildContext context, T item, Widget tile)? itemWrapper;

  @override
  State<SourceFeedGrid<T>> createState() => _SourceFeedGridState<T>();
}

class _SourceFeedGridState<T extends FeedItemEntity> extends State<SourceFeedGrid<T>> {
  final GlobalKey<RefreshIndicatorState> refreshHomeKey = GlobalKey<RefreshIndicatorState>();
  final ScrollMilestoneTracker _scrollMilestoneTracker = ScrollMilestoneTracker();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();

  @override
  void initState() {
    super.initState();
    _contentLoadTracker.start();
  }

  Future<void> refreshList() async {
    refreshHomeKey.currentState?.show();
    _contentLoadTracker.start();
    _scrollMilestoneTracker.reset();
    context.read<CategoryFeedBloc>().add(const CategoryFeedEvent.refreshRequested());
  }

  void _loadMore() => context.read<CategoryFeedBloc>().add(const CategoryFeedEvent.fetchMoreRequested());

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
            _loadMore();
          }
          return false;
        },
        child: GridView.builder(
          physics: widget.physics,
          padding: EdgeInsets.zero,
          itemCount: walls.isEmpty ? 20 : walls.length + (state.hasMore ? 1 : 0),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: wallpaperGridColumns(MediaQuery.sizeOf(context).width),
            childAspectRatio: 0.5,
          ),
          itemBuilder: (context, index) {
            if (walls.isEmpty) {
              return Container(
                decoration: BoxDecoration(
                  color: context.isDarkMode ? Colors.white10 : Colors.black.withValues(alpha: .1),
                ),
              );
            }
            if (index == walls.length) {
              return SeeMoreButton(
                seeMoreLoader: state.isFetchingMore,
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
                  _loadMore();
                },
              );
            }
            final Widget tile = WallpaperTile(item: walls[index], index: index);
            return widget.itemWrapper?.call(context, walls[index], tile) ?? tile;
          },
        ),
      ),
    );
  }
}
