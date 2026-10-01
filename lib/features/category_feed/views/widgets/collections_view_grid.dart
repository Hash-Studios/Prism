import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> walls = anyCollectionWalls;
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
      child: PulsePlaceholder(
        builder: (context, _) => GridView.builder(
          padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
          itemCount: walls.length + (collectionHasMore && walls.length >= 24 ? 1 : 0),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
            childAspectRatio: 0.6625,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            if (index == walls.length && collectionHasMore && walls.length >= 24) {
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
              return Container(
                decoration: BoxDecoration(color: Theme.of(context).hintColor.withValues(alpha: 0.08)),
                child: Center(child: Icon(Icons.broken_image_outlined, color: Theme.of(context).colorScheme.secondary)),
              );
            }
            return Semantics(
              button: true,
              label: wallpaperSemanticLabel(_wallString(wall, 'by')),
              child: ShakeOnce(
                controller: _shake,
                target: index,
                child: Stack(
                  children: [
                    PrismImageTile(url: wallpaperThumb, heroTag: prismHeroTag(this, index, wallId)),
                    ClipRect(
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
                            PrismHaptics.impact();
                            createDynamicLink(wallId, wallSource, wallpaperUrl, wallpaperThumb);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
