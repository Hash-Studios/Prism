import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CollectionViewGrid extends StatefulWidget {
  const CollectionViewGrid();
  @override
  _CollectionViewGridState createState() => _CollectionViewGridState();
}

class _CollectionViewGridState extends State<CollectionViewGrid> {
  final ShakeController _shake = ShakeController();
  final ScrollMilestoneTracker _scrollMilestoneTracker = ScrollMilestoneTracker();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();

  bool seeMoreLoader = false;

  Object? _wallValue(Map<String, dynamic> wall, String key) => wall[key];
  String _wallString(Map<String, dynamic> wall, String key) => _wallValue(wall, key)?.toString() ?? '';
  WallpaperSource _wallSource(Map<String, dynamic> wall) =>
      WallpaperSourceX.fromWire(_wallString(wall, 'wallpaper_provider'));

  Future<void> _loadMore() async {
    if (seeMoreLoader || !collectionHasMore) {
      return;
    }
    setState(() {
      seeMoreLoader = true;
    });
    try {
      await seeMoreCollectionWithName();
    } finally {
      if (mounted) {
        setState(() {
          seeMoreLoader = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _contentLoadTracker.start();
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  /// Curated collections show two wallpapers across on a phone, more on a wide screen.
  int _columns(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double target = media.orientation == Orientation.portrait ? 300 : 250;
    return (media.size.width / target).ceil().clamp(2, 6);
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> walls = anyCollectionWalls;
    final bool showSeeMore = collectionHasMore && walls.length >= 24;
    if (walls.isEmpty) {
      return const GlintState(
        kind: GlintStateKind.empty,
        title: 'Nothing in this collection yet',
        body: 'New wallpapers are added often. Check back soon.',
      );
    }
    if (walls.isNotEmpty) {
      _contentLoadTracker.success(
        itemCount: walls.length,
        onSuccess: ({required int loadTimeMs, int? itemCount}) async {
          await analytics.track(
            SurfaceContentLoadedEvent(
              surface: AnalyticsSurfaceValue.homeCollectionsViewGrid,
              result: EventResultValue.success,
              loadTimeMs: loadTimeMs,
              sourceContext: 'home_collections_grid_initial',
              itemCount: itemCount,
            ),
          );
        },
      );
    }
    final ColorScheme cs = Theme.of(context).colorScheme;
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        _scrollMilestoneTracker.onScroll(
          metrics: notification.metrics,
          itemCount: walls.length,
          onMilestoneReached: (depth, {required int itemCount}) async {
            await analytics.track(
              ScrollMilestoneReachedEvent(
                surface: AnalyticsSurfaceValue.homeCollectionsViewGrid,
                listName: ScrollListNameValue.collectionsViewGrid,
                depth: depth,
                sourceContext: 'home_collections_grid_scroll',
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
        itemCount: walls.length + (showSeeMore ? 1 : 0),
        gridDelegate: PrismWallGrid.delegate(context, columns: _columns(context), aspectRatio: 0.6625),
        itemBuilder: (context, index) {
          if (index == walls.length && showSeeMore) {
            return SeeMoreButton(
              seeMoreLoader: seeMoreLoader,
              func: () {
                unawaited(
                  analytics.track(
                    const SurfaceActionTappedEvent(
                      surface: AnalyticsSurfaceValue.homeCollectionsViewGrid,
                      action: AnalyticsActionValue.seeMoreTapped,
                      sourceContext: 'home_collections_grid_see_more',
                    ),
                  ),
                );
                _loadMore();
              },
            );
          }
          final Map<String, dynamic> wall = walls[index];
          final String wallId = _wallString(wall, 'id');
          final String wallpaperThumb = normalizeWallpaperThumbnailUrl(_wallString(wall, 'wallpaper_thumb'));
          final String wallpaperUrl = _wallString(wall, 'wallpaper_url');
          final WallpaperSource wallSource = _wallSource(wall);
          final bool validPayload =
              wallId.trim().isNotEmpty && isValidNetworkUrl(wallpaperThumb) && isValidNetworkUrl(wallpaperUrl);
          if (!validPayload) {
            logger.w(
              'Skipping malformed collection tile payload.',
              tag: 'CollectionsGrid',
              fields: <String, Object?>{'wall_id': wallId, 'thumb': wallpaperThumb, 'url': wallpaperUrl},
            );
            return DecoratedBox(
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.06),
                borderRadius: PrismWallGrid.tileRadius,
              ),
              child: Center(child: Icon(Icons.broken_image_outlined, color: cs.onSurface.withValues(alpha: 0.4))),
            );
          }
          return ShakeOnce(
            controller: _shake,
            target: index,
            child: PrismWallTile(
              url: wallpaperThumb,
              heroTag: prismHeroTag(this, index, wallId),
              semanticLabel: wallpaperSemanticLabel(_wallString(wall, 'by')),
              onTap: () {
                unawaited(
                  analytics.track(
                    SurfaceActionTappedEvent(
                      surface: AnalyticsSurfaceValue.homeCollectionsViewGrid,
                      action: AnalyticsActionValue.tileOpened,
                      sourceContext: 'home_collections_grid_tile',
                      itemType: ItemTypeValue.wallpaper,
                      itemId: wallId,
                      index: index,
                    ),
                  ),
                );
                context.router.push(
                  WallpaperDetailRoute(
                    wallId: wallId,
                    source: wallSource,
                    thumbnailUrl: wallpaperThumb,
                    analyticsSurface: AnalyticsSurfaceValue.shareWallpaperView,
                    heroTag: prismHeroTag(this, index, wallId),
                  ),
                );
              },
              onLongPress: () {
                _shake.shake(index);
                HapticFeedback.vibrate();
                createDynamicLink(wallId, wallSource, wallpaperUrl, wallpaperThumb);
              },
            ),
          );
        },
      ),
    );
  }
}
