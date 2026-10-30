import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/widgets/depth_tag.dart';
import 'package:Prism/core/widgets/home/feed_scroll.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/spatial_tag.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/l10n/l10n.dart';
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

  static const int _maxEmptyPages = 5;

  bool seeMoreLoader = false;
  int _emptyPagesLoaded = 0;
  bool _emptyPageLoadScheduled = false;
  bool _loadMoreFailed = false;

  Object? _wallValue(Map<String, dynamic> wall, String key) => wall[key];
  String _wallString(Map<String, dynamic> wall, String key) => _wallValue(wall, key)?.toString() ?? '';

  /// The wall as the detail screen and the quick actions use it, so no second fetch is needed.
  FeedItemEntity _entityFor(Map<String, dynamic> wall, String wallId) => PrismFeedItem(
    id: wallId,
    wallpaper: PrismWallDocDto.fromJson(wall).toDomain(docId: wallId),
  );

  List<Map<String, dynamic>> _visibleWalls() => AiContentFilter.showsAi(getIt<SettingsLocalDataSource>())
      ? anyCollectionWalls
      : anyCollectionWalls.where((wall) => !_isAiWall(wall)).toList(growable: false);

  Set<String> _visibleWallIds() =>
      _visibleWalls().map((wall) => _wallString(wall, 'id')).where((id) => id.isNotEmpty).toSet();

  bool _preservesLoadedWalls(List<Map<String, dynamic>> previous, List<Map<String, dynamic>> current) {
    if (identical(previous, current) || current.length < previous.length) return false;
    for (int index = 0; index < previous.length; index++) {
      if (!identical(current[index], previous[index])) return false;
    }
    return true;
  }

  bool _isAiWall(Map<String, dynamic> wall) =>
      AiContentFilter.isAi(PrismWallDocDto.fromJson(wall).toDomain(docId: _wallString(wall, 'id')));

  Future<void> _showAiAgain() async {
    await setShowAiWallpapers(getIt<SettingsLocalDataSource>(), true);
    if (mounted) await _refresh();
  }

  Future<void> _refresh() async {
    PrismHaptics.impact();
    try {
      await refreshCollectionWithName();
    } catch (error, stackTrace) {
      logger.w('Failed to refresh the collection.', error: error, stackTrace: stackTrace);
      if (mounted) toasts.error(context.l10n.wallpaperCollectionRefreshError);
    }
    if (mounted) {
      setState(() {
        _loadMoreFailed = false;
        _emptyPagesLoaded = 0;
      });
    }
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
      // Hidden AI walls can fill whole pages, so keep going until a visible wall arrives.
      final bool showAiAtStart = AiContentFilter.showsAi(getIt<SettingsLocalDataSource>());
      final Set<String> visibleBefore = _visibleWallIds();
      for (int page = 0; page < _maxEmptyPages; page++) {
        final List<Map<String, dynamic>> previousWalls = anyCollectionWalls;
        await seeMoreCollectionWithName();
        if (!mounted ||
            showAiAtStart ||
            AiContentFilter.showsAi(getIt<SettingsLocalDataSource>()) ||
            !_preservesLoadedWalls(previousWalls, anyCollectionWalls) ||
            !collectionHasMore ||
            _visibleWallIds().difference(visibleBefore).isNotEmpty) {
          break;
        }
      }
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

  /// Curated collections show two wallpapers across on a phone, more on a wide screen.
  int _columns(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double target = media.orientation == Orientation.portrait ? 300 : 250;
    return (media.size.width / target).ceil().clamp(2, 6);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: personalizedFeedSettingsRevision,
      builder: (context, _, _) => _buildGrid(context),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final bool hideAi = !AiContentFilter.showsAi(getIt<SettingsLocalDataSource>());
    final List<Map<String, dynamic>> loaded = anyCollectionWalls;
    final List<Map<String, dynamic>> walls = _visibleWalls();
    if (walls.isNotEmpty || !hideAi) _emptyPagesLoaded = 0;
    if (walls.isEmpty && hideAi && loaded.isNotEmpty) {
      if (seeMoreLoader) return const Center(child: CircularProgressIndicator());
      if (_loadMoreFailed) {
        return PrismInlineState(
          icon: Icons.error_outline_rounded,
          title: context.l10n.wallpaperFeedWallsLoadError,
          actionLabel: context.l10n.wallpaperTryAgain,
          onAction: () => unawaited(_loadMore()),
        );
      }
      if (collectionHasMore && _emptyPagesLoaded < _maxEmptyPages) {
        if (!seeMoreLoader && !_emptyPageLoadScheduled) {
          _emptyPageLoadScheduled = true;
          final int settingsRevision = personalizedFeedSettingsRevision.value;
          final List<Map<String, dynamic>> scheduledWalls = loaded;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _emptyPageLoadScheduled = false;
            if (!mounted) return;
            if (settingsRevision != personalizedFeedSettingsRevision.value ||
                !identical(anyCollectionWalls, scheduledWalls)) {
              setState(() {});
              return;
            }
            if (collectionHasMore && !seeMoreLoader) {
              _emptyPagesLoaded = _maxEmptyPages;
              unawaited(_loadMore());
            }
          });
        }
        return const Center(child: CircularProgressIndicator());
      }
      if (collectionHasMore) {
        return PrismInlineState(
          icon: Icons.auto_awesome_rounded,
          title: context.l10n.wallpaperCollectionsEmptyTitle,
          body: context.l10n.wallpaperCollectionsEmptyBody,
          actionLabel: context.l10n.wallpaperTryAgain,
          onAction: () => unawaited(_loadMore()),
        );
      }
      return Center(
        child: PrismInlineState(
          icon: Icons.auto_awesome_rounded,
          title: context.l10n.feedNoHumanWalls,
          actionLabel: context.l10n.feedShowAiWalls,
          onAction: _showAiAgain,
        ),
      );
    }
    if (walls.isEmpty && !collectionHasMore) {
      return GlintState(
        kind: GlintStateKind.empty,
        title: context.l10n.wallpaperCollectionsEmptyTitle,
        body: context.l10n.wallpaperCollectionsEmptyBody,
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int columns = _columns(context);
    final int decodeHeight = gridTileDecodeHeight(context, crossAxisCount: columns, aspectRatio: 0.6625);
    return RefreshIndicator(
      backgroundColor: cs.surfaceContainerHigh,
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
          padding: PrismWallGrid.padding.copyWith(
            top: PrismSpace.xxs,
            bottom: MediaQuery.paddingOf(context).bottom + PrismSpace.md,
          ),
          itemCount: walls.length + (showFooter ? 1 : 0),
          gridDelegate: PrismWallGrid.delegate(
            context,
            footerHeight: favouriteFooterHeight,
            columns: columns,
            aspectRatio: 0.6625,
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
            final bool protectedPreview = wall['originalProtected'] == true && wallpaperUrl.isEmpty;
            final bool validPayload =
                wallId.trim().isNotEmpty &&
                isValidNetworkUrl(wallpaperThumb) &&
                (protectedPreview || isValidNetworkUrl(wallpaperUrl));
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
            final FeedItemEntity entity = _entityFor(wall, wallId);
            return KeyedSubtree(
              key: ValueKey<String>(wallId),
              child: FavouriteWallpaperCard(
                item: entity,
                child: PrismWallTile(
                  url: wallpaperThumb,
                  fallbackUrl: wallpaperUrl,
                  memCacheHeight: decodeHeight,
                  heroTag: prismHeroTag(this, index, wallId),
                  semanticLabel: wallpaperSemanticLabel(_wallString(wall, 'by'), context.l10n),
                  overlay: stackTags(<Widget?>[
                    depthTagFor(depthTierOf(entity)),
                    spatialTagFor(spatialOf(entity)?.tier),
                  ]),
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
                        entity: entity,
                        analyticsSurface: AnalyticsSurfaceValue.shareWallpaperView,
                        heroTag: prismHeroTag(this, index, wallId),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
