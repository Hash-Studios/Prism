import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/core/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as PData;
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/features/navigation/views/widgets/inherited_scroll_controller_provider.dart';
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
    PData.wallsC = [];
    PData.getWallsPbyColor(widget.provider.substring(9));
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
    final ScrollController? controller = InheritedDataProvider.of(context)!.scrollController;
    if (PData.wallsC.isNotEmpty) {
      _contentLoadTracker.success(
        itemCount: PData.wallsC.length,
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
            itemCount: PData.wallsC.length,
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
              PData.getWallsPbyColorPage(widget.provider.substring(9));
              setState(() {
                seeMoreLoader = true;
                Future.delayed(const Duration(seconds: 2)).then((value) => seeMoreLoader = false);
              });
            }
          }
          return false;
        },
        child: GridView.builder(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
          itemCount: PData.wallsC.isEmpty ? 24 : PData.wallsC.length,
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
            childAspectRatio: 0.6625,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            if (index == PData.wallsC.length - 1) {
              return MaterialButton(
                color: context.prismModeStyleForContext() == "Dark"
                    ? Colors.white10
                    : Colors.black.withValues(alpha: .1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: () {
                  unawaited(
                    analytics.track(
                      SurfaceActionTappedEvent(
                        surface: AnalyticsSurfaceValue.homeColorGrid,
                        action: AnalyticsActionValue.seeMoreTapped,
                        sourceContext: 'home_color_grid_see_more',
                      ),
                    ),
                  );
                  if (!seeMoreLoader) {
                    PData.getWallsPbyColorPage(widget.provider.substring(9));
                    setState(() {
                      seeMoreLoader = true;
                      Future.delayed(const Duration(seconds: 2)).then((value) => seeMoreLoader = false);
                    });
                  }
                },
                child: !seeMoreLoader ? const Text("See more") : Loader(),
              );
            }

            return FocusedMenuHolder(
              provider: widget.provider,
              index: index,
              child: AnimatedBuilder(
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
                          decoration: PData.wallsC.isEmpty
                              ? BoxDecoration(color: animation.value, borderRadius: BorderRadius.circular(20))
                              : BoxDecoration(
                                  color: animation.value,
                                  borderRadius: BorderRadius.circular(20),
                                  image: DecorationImage(
                                    image: CachedNetworkImageProvider(PData.wallsC[index].src!["medium"].toString()),
                                    fit: BoxFit.cover,
                                  ),
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
                                if (PData.wallsC == []) {
                                } else {
                                  unawaited(
                                    analytics.track(
                                      SurfaceActionTappedEvent(
                                        surface: AnalyticsSurfaceValue.homeColorGrid,
                                        action: AnalyticsActionValue.tileOpened,
                                        sourceContext: 'home_color_grid_tile',
                                        itemType: ItemTypeValue.wallpaper,
                                        itemId: PData.wallsC[index].id?.toString(),
                                        index: index,
                                      ),
                                    ),
                                  );
                                  context.router.push(
                                    WallpaperRoute(
                                      provider: widget.provider,
                                      index: index,
                                      link: PData.wallsC[index].src!["small"].toString(),
                                    ),
                                  );
                                }
                              },
                              onLongPress: () {
                                setState(() {
                                  longTapIndex = index;
                                });
                                shakeController.forward(from: 0.0);
                                if (PData.wallsC == []) {
                                } else {
                                  HapticFeedback.vibrate();
                                  createDynamicLink(
                                    PData.wallsC[index].id!,
                                    "Pexels",
                                    PData.wallsC[index].src!["original"].toString(),
                                    PData.wallsC[index].src!["medium"].toString(),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
