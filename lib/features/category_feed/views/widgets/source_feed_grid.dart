import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/analytics/trackers/wallpaper_impression.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/widgets/home/feed_scroll.dart';
import 'package:Prism/core/widgets/home/refreshable_glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/category_feed_refresh.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shared grid body for a single [FeedItemEntity] subtype. Only the item
/// subtype `T` and the analytics constants below differ between sources.
class SourceFeedGrid<T extends FeedItemEntity> extends StatefulWidget {
  const SourceFeedGrid({
    super.key,
    required this.surface,
    required this.listName,
    required this.sourceContextPrefix,
    this.itemWrapper,
    this.includePrism = false,
  });

  final AnalyticsSurfaceValue surface;
  final ScrollListNameValue listName;
  final String sourceContextPrefix;
  final Widget Function(BuildContext context, T item, Widget tile)? itemWrapper;

  /// Also shows Prism walls. A category on Wallhaven or Pexels starts with creator walls from Prism.
  final bool includePrism;

  @override
  State<SourceFeedGrid<T>> createState() => _SourceFeedGridState<T>();
}

class _SourceFeedGridState<T extends FeedItemEntity> extends State<SourceFeedGrid<T>> {
  final ScrollMilestoneTracker _scrollMilestoneTracker = ScrollMilestoneTracker();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();
  WallpaperImpressionSession _impressions = WallpaperImpressionSession();
  int _refreshVersion = 0;

  @override
  void initState() {
    super.initState();
    _contentLoadTracker.start();
  }

  Future<void> _refresh() async {
    final CategoryFeedBloc bloc = context.read<CategoryFeedBloc>();
    final category = bloc.state.selectedCategory;
    final int refreshVersion = ++_refreshVersion;
    _contentLoadTracker.start();
    _scrollMilestoneTracker.reset();
    await refreshCategoryFeed(bloc);
    if (mounted &&
        refreshVersion == _refreshVersion &&
        category != null &&
        bloc.state.selectedCategory == category &&
        bloc.state.status == LoadStatus.success &&
        bloc.state.actionStatus == ActionStatus.success) {
      setState(() => _impressions = WallpaperImpressionSession());
    }
  }

  void _loadMore() => context.read<CategoryFeedBloc>().add(const CategoryFeedEvent.fetchMoreRequested());

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: personalizedFeedSettingsRevision,
      builder: (context, _, _) => _buildGrid(context),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final CategoryFeedState state = context.watch<CategoryFeedBloc>().state;
    final bool showAi = AiContentFilter.showsAi(getIt<SettingsLocalDataSource>());
    final List<FeedItemEntity> walls = state.items
        .where((item) => item is T || (widget.includePrism && item is PrismFeedItem))
        .where((item) => showAi || item is! PrismFeedItem || !AiContentFilter.isAi(item.wallpaper))
        .toList(growable: false);

    if (walls.isEmpty) {
      if (state.status == LoadStatus.initial || state.status == LoadStatus.loading) {
        return const LoadingCards();
      }
      final bool failed = state.status == LoadStatus.failure || state.actionStatus == ActionStatus.failure;
      final bool canContinue = state.status == LoadStatus.success && state.hasMore;
      return RefreshableGlintState(
        kind: failed ? GlintStateKind.error : GlintStateKind.empty,
        title: failed ? context.l10n.wallpaperFeedWallsLoadError : context.l10n.wallpaperCategoryFeedEmptyTitle,
        body: failed ? context.l10n.wallpaperCheckConnection : context.l10n.wallpaperCategoryFeedEmptyBody,
        actionLabel: failed || canContinue ? context.l10n.wallpaperTryAgain : context.l10n.wallpaperRefresh,
        onAction: () {
          if (canContinue) {
            _loadMore();
          } else {
            unawaited(_refresh());
          }
        },
        onRefresh: _refresh,
      );
    }

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

    final bool loadFailed = state.actionStatus == ActionStatus.failure;
    final bool refreshFailed = state.status == LoadStatus.failure;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      color: cs.primary,
      backgroundColor: cs.surfaceContainerHigh,
      onRefresh: () {
        PrismHaptics.impact();
        return _refresh();
      },
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
          if (!loadFailed && isNearFeedEnd(scrollInfo.metrics)) {
            _loadMore();
          }
          return false;
        },
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          scrollCacheExtent: const ScrollCacheExtent.viewport(1.5),
          padding: PrismWallGrid.padding.copyWith(
            top: PrismSpace.xxs,
            bottom: MediaQuery.paddingOf(context).bottom + PrismSpace.md,
          ),
          itemCount: walls.length + (state.hasMore ? 1 : 0),
          gridDelegate: PrismWallGrid.delegate(context, footerHeight: favouriteFooterHeight),
          itemBuilder: (context, index) {
            if (index == walls.length) {
              return SeeMoreButton(
                seeMoreLoader: state.isFetchingMore,
                failed: loadFailed,
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
                  if (loadFailed && refreshFailed) {
                    unawaited(_refresh());
                  } else {
                    _loadMore();
                  }
                },
              );
            }
            final FeedItemEntity item = walls[index];
            final Widget tile = WallpaperTile(
              item: item,
              index: index,
              impressionSession: _impressions,
              sourceContext: widget.includePrism && item is PrismFeedItem ? 'category_prism_first' : null,
              feed: walls,
            );
            return KeyedSubtree(
              key: ValueKey<String>(item.id),
              child: item is T ? widget.itemWrapper?.call(context, item, tile) ?? tile : tile,
            );
          },
        ),
      ),
    );
  }
}
