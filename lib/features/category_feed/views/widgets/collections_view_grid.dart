import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/feed_scroll.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class CollectionViewGrid extends StatefulWidget {
  const CollectionViewGrid();
  @override
  _CollectionViewGridState createState() => _CollectionViewGridState();
}

class _CollectionViewGridState extends State<CollectionViewGrid> {
  final ScrollMilestoneTracker _scrollMilestoneTracker = ScrollMilestoneTracker();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();

  bool seeMoreLoader = false;
  bool _loadMoreFailed = false;

  Object? _wallValue(Map<String, dynamic> wall, String key) => wall[key];
  String _wallString(Map<String, dynamic> wall, String key) => _wallValue(wall, key)?.toString() ?? '';

  /// The wall as the detail screen and the quick actions use it, so no second fetch is needed.
  FeedItemEntity _entityFor(Map<String, dynamic> wall, String wallId) => PrismFeedItem(
    id: wallId,
    wallpaper: PrismWallDocDto.fromJson(wall).toDomain(docId: wallId),
  );

  Future<void> _refresh() async {
    PrismHaptics.impact();
    try {
      await refreshCollectionWithName();
    } catch (error, stackTrace) {
      logger.w('Failed to refresh the collection.', error: error, stackTrace: stackTrace);
      toasts.error("Couldn't refresh. Pull down to try again.");
    }
    if (mounted) setState(() => _loadMoreFailed = false);
  }

  Future<void> _loadMore() async {
    if (seeMoreLoader || !collectionHasMore) {
      return;
    }
    setState(() {
      seeMoreLoader = true;
      _loadMoreFailed = false;
    });
    try {
      await seeMoreCollectionWithName();
    } catch (error, stackTrace) {
      logger.w('Failed to load more collection walls.', error: error, stackTrace: stackTrace);
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

  @override
  void initState() {
    super.initState();
    _contentLoadTracker.start();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> walls = anyCollectionWalls;
    if (walls.isEmpty && !collectionHasMore) {
      return const GlintState(
        kind: GlintStateKind.empty,
        title: 'No wallpapers in this collection yet',
        body: 'Check back soon.',
      );
    }
    final bool showFooter = collectionHasMore;
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
    final int columns = (MediaQuery.sizeOf(context).width / 300).ceil().clamp(1, 8);
    final int decodeHeight = gridTileDecodeHeight(context, crossAxisCount: columns, aspectRatio: 0.6625);
    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
      onRefresh: _refresh,
      child: NotificationListener<ScrollNotification>(
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
          if (showFooter && !_loadMoreFailed && isNearFeedEnd(notification.metrics)) {
            unawaited(_loadMore());
          }
          return false;
        },
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          scrollCacheExtent: const ScrollCacheExtent.viewport(1.5),
          padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
          itemCount: walls.length + (showFooter ? 1 : 0),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
            childAspectRatio: 0.6625,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            if (index == walls.length && showFooter) {
              return SeeMoreButton(
                seeMoreLoader: seeMoreLoader,
                failed: _loadMoreFailed,
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
            return KeyedSubtree(
              key: ValueKey<String>(wallId),
              child: Semantics(
                button: true,
                label: wallpaperSemanticLabel(_wallString(wall, 'by')),
                child: ClipRect(
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
                            entity: _entityFor(wall, wallId),
                            analyticsSurface: AnalyticsSurfaceValue.shareWallpaperView,
                            heroTag: prismHeroTag(this, index, wallId),
                          ),
                        );
                      },
                      onLongPress: () {
                        PrismHaptics.impact();
                        unawaited(showWallpaperQuickActions(context, _entityFor(wall, wallId)));
                      },
                      child: PrismImageTile(
                        url: wallpaperThumb,
                        fallbackUrl: wallpaperUrl,
                        memCacheHeight: decodeHeight,
                        heroTag: prismHeroTag(this, index, wallId),
                      ),
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
