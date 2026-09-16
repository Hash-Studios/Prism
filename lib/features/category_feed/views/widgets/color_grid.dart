import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/data/pexels/provider/pexels_without_provider.dart' as pexels_data;
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ColorGrid extends StatefulWidget {
  final String provider;
  const ColorGrid({required this.provider});
  @override
  _ColorGridState createState() => _ColorGridState();
}

class _ColorGridState extends State<ColorGrid> with TickerProviderStateMixin {
  AnimationController? _controller;
  late AnimationController shakeController;
  late Animation<Color?> animation;
  int? longTapIndex;
  GlobalKey<RefreshIndicatorState> refreshHomeKey = GlobalKey<RefreshIndicatorState>();
  final ScrollMilestoneTracker _scrollMilestoneTracker = ScrollMilestoneTracker();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();

  bool seeMoreLoader = false;
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

  Future<void> refreshList() async {
    refreshHomeKey.currentState?.show();
    _contentLoadTracker.start();
    _scrollMilestoneTracker.reset();
    pexels_data.wallsC = [];
    pexels_data.getWallsPbyColor(widget.provider.substring(9));
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
    if (pexels_data.wallsC.isNotEmpty) {
      _contentLoadTracker.success(
        itemCount: pexels_data.wallsC.length,
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
    }
    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
      key: refreshHomeKey,
      onRefresh: refreshList,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          _scrollMilestoneTracker.onScroll(
            metrics: scrollInfo.metrics,
            itemCount: pexels_data.wallsC.length,
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
            if (!seeMoreLoader) {
              pexels_data.getWallsPbyColorPage(widget.provider.substring(9));
              setState(() {
                seeMoreLoader = true;
                Future.delayed(const Duration(seconds: 2)).then((value) => seeMoreLoader = false);
              });
            }
          }
          return false;
        },
        child: GridView.builder(
          padding: EdgeInsets.zero,
          itemCount: pexels_data.wallsC.isEmpty ? 24 : pexels_data.wallsC.length,
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).orientation == Orientation.portrait ? 3 : 5,
            childAspectRatio: 0.5,
          ),
          itemBuilder: (context, index) {
            if (index == pexels_data.wallsC.length - 1) {
              return MaterialButton(
                color: context.prismModeStyleForContext() == "Dark"
                    ? Colors.white10
                    : Colors.black.withValues(alpha: .1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: () {
                  unawaited(
                    analytics.track(
                      const SurfaceActionTappedEvent(
                        surface: AnalyticsSurfaceValue.homeColorGrid,
                        action: AnalyticsActionValue.seeMoreTapped,
                        sourceContext: 'home_color_grid_see_more',
                      ),
                    ),
                  );
                  if (!seeMoreLoader) {
                    pexels_data.getWallsPbyColorPage(widget.provider.substring(9));
                    setState(() {
                      seeMoreLoader = true;
                      Future.delayed(const Duration(seconds: 2)).then((value) => seeMoreLoader = false);
                    });
                  }
                },
                child: !seeMoreLoader ? const Text("See more") : Loader(),
              );
            }

            final tile = AnimatedBuilder(
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
                        decoration: pexels_data.wallsC.isEmpty
                            ? BoxDecoration(color: animation.value)
                            : BoxDecoration(
                                color: animation.value,
                                image: DecorationImage(
                                  image: CachedNetworkImageProvider(pexels_data.wallsC[index].core.thumbnailUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                          highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                          onTap: () {
                            if (pexels_data.wallsC.isEmpty) {
                            } else {
                              unawaited(
                                analytics.track(
                                  SurfaceActionTappedEvent(
                                    surface: AnalyticsSurfaceValue.homeColorGrid,
                                    action: AnalyticsActionValue.tileOpened,
                                    sourceContext: 'home_color_grid_tile',
                                    itemType: ItemTypeValue.wallpaper,
                                    itemId: pexels_data.wallsC[index].id,
                                    index: index,
                                  ),
                                ),
                              );
                              context.router.push(
                                WallpaperDetailRoute(
                                  entity: PexelsDetailEntity(wallpaper: pexels_data.wallsC[index]),
                                  analyticsSurface: AnalyticsSurfaceValue.searchWallpaperScreen,
                                ),
                              );
                            }
                          },
                          onLongPress: () {
                            setState(() {
                              longTapIndex = index;
                            });
                            shakeController.forward(from: 0.0);
                            if (pexels_data.wallsC.isEmpty) {
                            } else {
                              HapticFeedback.vibrate();
                              createDynamicLink(
                                pexels_data.wallsC[index].id,
                                WallpaperSource.pexels,
                                pexels_data.wallsC[index].core.fullUrl,
                                pexels_data.wallsC[index].core.thumbnailUrl,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );

            return tile;
          },
        ),
      ),
    );
  }
}
