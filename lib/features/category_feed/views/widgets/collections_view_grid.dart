import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/home/wallpapers/seeMoreButton.dart';
import 'package:Prism/data/collections/provider/collectionsWithoutProvider.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CollectionViewGrid extends StatefulWidget {
  const CollectionViewGrid();
  @override
  _CollectionViewGridState createState() => _CollectionViewGridState();
}

class _CollectionViewGridState extends State<CollectionViewGrid> with TickerProviderStateMixin {
  AnimationController? _controller;
  late AnimationController shakeController;
  late Animation<Color?> animation;
  int? longTapIndex;
  GlobalKey<RefreshIndicatorState> refreshHomeKey = GlobalKey<RefreshIndicatorState>();
  final ScrollMilestoneTracker _scrollMilestoneTracker = ScrollMilestoneTracker();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();

  bool seeMoreLoader = false;

  Object? _wallValue(Map<String, dynamic> wall, String key) => wall[key];
  String _wallString(Map<String, dynamic> wall, String key) => _wallValue(wall, key)?.toString() ?? '';
  WallpaperSource _wallSource(Map<String, dynamic> wall) =>
      WallpaperSourceX.fromWire(_wallString(wall, 'wallpaper_provider'));
  bool _isValidRemoteUrl(String value) {
    final Uri? uri = Uri.tryParse(value.trim());
    if (uri == null) {
      return false;
    }
    return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

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
    shakeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    animation =
        context.prismModeStyleForWindow(listen: false) == "Dark"
              ? TweenSequence<Color?>([
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(begin: Colors.white10, end: const Color(0x22FFFFFF)),
                  ),
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(begin: const Color(0x22FFFFFF), end: Colors.white10),
                  ),
                ]).animate(_controller!)
              : TweenSequence<Color?>([
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(
                      begin: Colors.black.withValues(alpha: .1),
                      end: Colors.black.withValues(alpha: .14),
                    ),
                  ),
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(
                      begin: Colors.black.withValues(alpha: .14),
                      end: Colors.black.withValues(alpha: .1),
                    ),
                  ),
                ]).animate(_controller!)
          ..addListener(() {
            setState(() {});
          });
    _controller!.repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> offsetAnimation =
        Tween(begin: 0.0, end: 8.0).chain(CurveTween(curve: Curves.easeOutCubic)).animate(shakeController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              shakeController.reverse();
            }
          });
    final ScrollController? controller = PrimaryScrollController.maybeOf(context);
    final List<Map<String, dynamic>> walls = anyCollectionWalls ?? <Map<String, dynamic>>[];
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
      child: GridView.builder(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
        itemCount: walls.length,
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
          childAspectRatio: 0.6625,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          final Map<String, dynamic> wall = walls[index];
          final String wallId = _wallString(wall, 'id');
          final String wallpaperThumb = _wallString(wall, 'wallpaper_thumb');
          final String wallpaperUrl = _wallString(wall, 'wallpaper_url');
          final WallpaperSource wallSource = _wallSource(wall);
          final bool validPayload =
              wallId.trim().isNotEmpty && _isValidRemoteUrl(wallpaperThumb) && _isValidRemoteUrl(wallpaperUrl);
          if (index == walls.length - 1 && collectionHasMore && walls.length >= 24) {
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
          if (!validPayload) {
            logger.w(
              'Skipping malformed collection tile payload.',
              tag: 'CollectionsGrid',
              fields: <String, Object?>{'wall_id': wallId, 'thumb': wallpaperThumb, 'url': wallpaperUrl},
            );
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).hintColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(child: Icon(Icons.broken_image_outlined, color: Theme.of(context).colorScheme.secondary)),
            );
          }
          return AnimatedBuilder(
            animation: offsetAnimation,
            builder: (buildContext, child) {
              if (offsetAnimation.value < 0.0) {
                logger.d('${offsetAnimation.value + 8.0}');
              }
              return Padding(
                padding: index == longTapIndex
                    ? EdgeInsets.symmetric(vertical: offsetAnimation.value / 2, horizontal: offsetAnimation.value)
                    : EdgeInsets.zero,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: animation.value,
                        borderRadius: BorderRadius.circular(20),
                        image: DecorationImage(image: CachedNetworkImageProvider(wallpaperThumb), fit: BoxFit.cover),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                          highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
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
                              ShareWallpaperViewRoute(
                                wallId: wallId,
                                source: wallSource,
                                wallpaperUrl: wallpaperUrl,
                                thumbnailUrl: wallpaperThumb,
                              ),
                            );
                          },
                          onLongPress: () {
                            setState(() {
                              longTapIndex = index;
                            });
                            shakeController.forward(from: 0.0);
                            HapticFeedback.vibrate();
                            createDynamicLink(wallId, wallSource, wallpaperUrl, wallpaperThumb);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
