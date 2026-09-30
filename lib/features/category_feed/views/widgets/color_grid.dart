import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ColorGrid extends StatefulWidget {
  const ColorGrid({super.key, required this.hexColor});

  /// Six hex digits, without `#`.
  final String hexColor;

  @override
  State<ColorGrid> createState() => _ColorGridState();
}

class _ColorGridState extends State<ColorGrid> {
  final PexelsWallpaperRepository _repository = getIt<PexelsWallpaperRepository>();
  final ShakeController _shake = ShakeController();
  final GlobalKey<RefreshIndicatorState> refreshHomeKey = GlobalKey<RefreshIndicatorState>();
  final ScrollMilestoneTracker _scrollMilestoneTracker = ScrollMilestoneTracker();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();

  /// Null until the first page has loaded.
  List<PexelsWallpaper>? _walls;
  bool _failed = false;
  bool seeMoreLoader = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _contentLoadTracker.start();
    unawaited(_loadFirstPage());
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  /// Null when the request failed.
  Future<List<PexelsWallpaper>?> _fetch({required bool refresh}) async {
    final result = await _repository.fetchColorFeed(hex: widget.hexColor, refresh: refresh);
    return result.fold(
      onSuccess: (walls) => walls,
      onFailure: (failure) {
        logger.e('Colour feed failed: ${failure.message}');
        return null;
      },
    );
  }

  Future<void> _loadFirstPage() async {
    final walls = await _fetch(refresh: true);
    if (!mounted) {
      return;
    }
    setState(() {
      _failed = walls == null;
      if (walls != null) {
        _walls = walls.isEmpty ? (_walls ?? walls) : walls;
        _hasMore = walls.isNotEmpty;
      } else {
        _walls ??= const <PexelsWallpaper>[];
      }
    });
  }

  Future<void> _loadMore() async {
    if (seeMoreLoader || !_hasMore) {
      return;
    }
    setState(() {
      seeMoreLoader = true;
    });
    try {
      final more = await _fetch(refresh: false);
      if (mounted && more != null) {
        setState(() {
          _walls = <PexelsWallpaper>[...?_walls, ...more];
          _hasMore = more.isNotEmpty;
        });
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
    refreshHomeKey.currentState?.show();
    _contentLoadTracker.start();
    _scrollMilestoneTracker.reset();
    await _loadFirstPage();
  }

  void _retry() {
    setState(() => _walls = null);
    unawaited(_loadFirstPage());
  }

  @override
  Widget build(BuildContext context) {
    final List<PexelsWallpaper>? walls = _walls;
    if (walls == null) {
      return const LoadingCards();
    }
    if (walls.isEmpty) {
      return _failed
          ? GlintState(
              kind: GlintStateKind.error,
              title: "Couldn't load wallpapers",
              body: 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: _retry,
            )
          : const GlintState(
              kind: GlintStateKind.empty,
              title: 'No wallpapers for this colour',
              body: 'Try a different colour.',
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      color: cs.primary,
      backgroundColor: cs.surfaceContainerHigh,
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
                  surface: AnalyticsSurfaceValue.homeColorGrid,
                  listName: ScrollListNameValue.colorGrid,
                  depth: depth,
                  sourceContext: 'home_color_grid_scroll',
                  itemCount: itemCount,
                ),
              );
            },
          );
          if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            unawaited(_loadMore());
          }
          return false;
        },
        child: GridView.builder(
          padding: PrismWallGrid.padding.copyWith(
            top: PrismSpace.xxs,
            bottom: MediaQuery.paddingOf(context).bottom + PrismSpace.md,
          ),
          itemCount: walls.length + (_hasMore ? 1 : 0),
          gridDelegate: PrismWallGrid.delegate(context),
          itemBuilder: (context, index) {
            if (_hasMore && index == walls.length) {
              return SeeMoreButton(
                seeMoreLoader: seeMoreLoader,
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
            return ShakeOnce(
              controller: _shake,
              target: index,
              child: PrismWallTile(
                url: wall.core.thumbnailUrl,
                heroTag: prismHeroTag(this, index, wall.id),
                semanticLabel: wallpaperSemanticLabel(wall.core.authorName),
                onTap: () {
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
                  _shake.shake(index);
                  HapticFeedback.vibrate();
                  createDynamicLink(wall.id, WallpaperSource.pexels, wall.core.fullUrl, wall.core.thumbnailUrl);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
