import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/feed_scroll.dart';
import 'package:Prism/core/widgets/home/refreshable_glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ColorGrid extends StatefulWidget {
  const ColorGrid({super.key, required this.hexColor, required this.name});

  /// Six hex digits, without `#`.
  final String hexColor;

  /// Colour name used in the search query, for example `Red`.
  final String name;

  @override
  State<ColorGrid> createState() => _ColorGridState();
}

class _ColorGridState extends State<ColorGrid> {
  final PexelsWallpaperRepository _repository = getIt<PexelsWallpaperRepository>();
  final ScrollMilestoneTracker _scrollMilestoneTracker = ScrollMilestoneTracker();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();

  /// Null until the first page has loaded.
  List<PexelsWallpaper>? _walls;
  bool seeMoreLoader = false;
  bool _hasMore = true;
  bool _firstPageFailed = false;
  bool _loadMoreFailed = false;

  @override
  void initState() {
    super.initState();
    _contentLoadTracker.start();
    unawaited(_loadFirstPage());
  }

  /// One page of results. Throws when the request fails, so a failure is never shown as an empty colour.
  Future<List<PexelsWallpaper>> _fetch({required bool refresh}) async {
    final result = await _repository.fetchColorFeed(hex: widget.hexColor, name: widget.name, refresh: refresh);
    return result.fold(
      onSuccess: (walls) => walls,
      onFailure: (failure) {
        logger.e('Colour feed failed.', error: failure, fields: <String, Object?>{'message': failure.message});
        throw Exception(failure.message);
      },
    );
  }

  Future<void> _loadFirstPage() async {
    try {
      final walls = await _fetch(refresh: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _walls = walls;
        _hasMore = walls.isNotEmpty;
        _firstPageFailed = false;
        _loadMoreFailed = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _firstPageFailed = true);
      if (_walls?.isNotEmpty ?? false) {
        toasts.error("Couldn't refresh. Showing what you had.");
      }
    }
  }

  Future<void> _retryFirstPage() {
    setState(() => _firstPageFailed = false);
    return _loadFirstPage();
  }

  Future<void> _loadMore() async {
    if (seeMoreLoader || !_hasMore) {
      return;
    }
    setState(() {
      seeMoreLoader = true;
      _loadMoreFailed = false;
    });
    try {
      final more = await _fetch(refresh: false);
      if (mounted) {
        setState(() {
          _walls = <PexelsWallpaper>[...?_walls, ...more];
          _hasMore = more.isNotEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadMoreFailed = true);
      }
    } finally {
      if (mounted) {
        setState(() {
          seeMoreLoader = false;
        });
      }
    }
  }

  Future<void> refreshList() async {
    _contentLoadTracker.start();
    _scrollMilestoneTracker.reset();
    await _loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    final List<PexelsWallpaper>? walls = _walls;
    if (walls == null) {
      return _firstPageFailed
          ? RefreshableGlintState(
              kind: GlintStateKind.error,
              title: "Couldn't load wallpapers",
              body: 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: () => unawaited(_retryFirstPage()),
              onRefresh: _retryFirstPage,
            )
          : const LoadingCards(useFeedLayout: true);
    }
    if (walls.isEmpty) {
      return RefreshableGlintState(
        kind: GlintStateKind.empty,
        title: 'No ${widget.name.toLowerCase()} wallpapers yet',
        body: 'Pull down to try again.',
        onRefresh: refreshList,
      );
    }
    _contentLoadTracker.success(
      itemCount: walls.length,
      onSuccess: ({required int loadTimeMs, int? itemCount}) async {
        await analytics.track(
          SurfaceContentLoadedEvent(
            surface: AnalyticsSurfaceValue.homeColorGrid,
            result: EventResultValue.success,
            loadTimeMs: loadTimeMs,
            sourceContext: 'home_color_grid_initial',
            itemCount: itemCount,
          ),
        );
      },
    );
    final int columns = wallpaperGridColumns(MediaQuery.sizeOf(context).width);
    final int decodeHeight = gridTileDecodeHeight(context, crossAxisCount: columns);
    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
      onRefresh: () {
        PrismHaptics.impact();
        return refreshList();
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          _scrollMilestoneTracker.onScroll(
            metrics: scrollInfo.metrics,
            itemCount: walls.length,
            onMilestoneReached: (depth, {required int itemCount}) async {
              await analytics.track(
                ScrollMilestoneReachedEvent(
                  surface: AnalyticsSurfaceValue.homeColorGrid,
                  listName: ScrollListNameValue.colorGrid,
                  depth: depth,
                  sourceContext: 'home_color_grid_scroll',
                  itemCount: itemCount,
                ),
              );
            },
          );
          if (!_loadMoreFailed && isNearFeedEnd(scrollInfo.metrics)) {
            unawaited(_loadMore());
          }
          return false;
        },
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          scrollCacheExtent: const ScrollCacheExtent.viewport(1.5),
          padding: EdgeInsets.zero,
          itemCount: walls.length + (_hasMore ? 1 : 0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, childAspectRatio: 0.5),
          itemBuilder: (context, index) {
            if (_hasMore && index == walls.length) {
              return SeeMoreButton(
                seeMoreLoader: seeMoreLoader,
                failed: _loadMoreFailed,
                func: () {
                  unawaited(
                    analytics.track(
                      const SurfaceActionTappedEvent(
                        surface: AnalyticsSurfaceValue.homeColorGrid,
                        action: AnalyticsActionValue.seeMoreTapped,
                        sourceContext: 'home_color_grid_see_more',
                      ),
                    ),
                  );
                  unawaited(_loadMore());
                },
              );
            }

            final PexelsWallpaper wall = walls[index];
            return KeyedSubtree(
              key: ValueKey<String>(wall.id),
              child: Semantics(
                button: true,
                label: wallpaperSemanticLabel(wall.core.authorName),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                    highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                    enableFeedback: false,
                    onTap: () {
                      PrismHaptics.tap();
                      unawaited(
                        analytics.track(
                          SurfaceActionTappedEvent(
                            surface: AnalyticsSurfaceValue.homeColorGrid,
                            action: AnalyticsActionValue.tileOpened,
                            sourceContext: 'home_color_grid_tile',
                            itemType: ItemTypeValue.wallpaper,
                            itemId: wall.id,
                            index: index,
                          ),
                        ),
                      );
                      context.router.push(
                        WallpaperDetailRoute(
                          entity: PexelsFeedItem(id: wall.id, wallpaper: wall),
                          analyticsSurface: AnalyticsSurfaceValue.searchWallpaperScreen,
                          heroTag: prismHeroTag(this, index, wall.id),
                        ),
                      );
                    },
                    onLongPress: () {
                      PrismHaptics.impact();
                      unawaited(showWallpaperQuickActions(context, PexelsFeedItem(id: wall.id, wallpaper: wall)));
                    },
                    child: PrismImageTile(
                      url: wall.core.thumbnailUrl,
                      fallbackUrl: wall.core.fullUrl,
                      memCacheHeight: decodeHeight,
                      heroTag: prismHeroTag(this, index, wall.id),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
