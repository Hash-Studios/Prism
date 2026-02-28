import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/core/widgets/home/wallpapers/carouselDots.dart';
import 'package:Prism/core/widgets/home/wallpapers/seeMoreButton.dart';
import 'package:Prism/core/widgets/premiumBanners/walls.dart';
import 'package:Prism/core/widgets/premiumBanners/wallsCarousel.dart';
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/navigation/views/widgets/inherited_scroll_controller_provider.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

class WallpaperGrid extends StatefulWidget {
  final String? provider;
  const WallpaperGrid({required this.provider});
  @override
  _WallpaperGridState createState() => _WallpaperGridState();
}

class _WallpaperGridState extends State<WallpaperGrid> {
  GlobalKey<RefreshIndicatorState> refreshHomeKey = GlobalKey<RefreshIndicatorState>();
  int _current = 0;
  bool seeMoreLoader = false;
  int _lastLoggedSubWallsCount = -1;
  final ScrollMilestoneTracker _scrollMilestoneTracker = ScrollMilestoneTracker();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();
  @override
  void initState() {
    super.initState();
    _contentLoadTracker.start();
  }

  Future<void> refreshList() async {
    refreshHomeKey.currentState?.show();
    _contentLoadTracker.start();
    _scrollMilestoneTracker.reset();
    logger.i("[WallpaperGrid] manual refresh", fields: <String, Object?>{"provider": widget.provider});
    Data.prismWalls = [];
    Data.subPrismWalls = [];
    await Data.getPrismWalls();
  }

  Future<void> _triggerSeeMore(List<dynamic> subWalls) async {
    if (seeMoreLoader || !Data.prismHasMore) {
      return;
    }
    if (!(Data.prismWallsDocSnaps?.isNotEmpty ?? false)) {
      logger.w("[WallpaperGrid] see more skipped: no doc snapshots");
      Data.prismHasMore = false;
      return;
    }
    setState(() {
      seeMoreLoader = true;
    });
    logger.d(
      "[WallpaperGrid] see more triggered",
      fields: <String, Object?>{"currentItems": subWalls.length, "docSnaps": Data.prismWallsDocSnaps?.length ?? 0},
    );
    try {
      await Data.seeMorePrism();
    } finally {
      if (mounted) {
        setState(() {
          seeMoreLoader = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController? controller = InheritedDataProvider.of(context)!.scrollController;
    final CarouselSliderController carouselController = CarouselSliderController();
    final List<dynamic> subWalls = Data.subPrismWalls?.cast<dynamic>() ?? <dynamic>[];
    if (_lastLoggedSubWallsCount != subWalls.length) {
      _lastLoggedSubWallsCount = subWalls.length;
      logger.d(
        "[WallpaperGrid] build",
        fields: <String, Object?>{
          "provider": widget.provider,
          "items": subWalls.length,
          "docSnaps": Data.prismWallsDocSnaps?.length ?? 0,
        },
      );
    }
    if (subWalls.isNotEmpty) {
      _contentLoadTracker.success(
        itemCount: subWalls.length,
        onSuccess: ({required int loadTimeMs, int? itemCount}) async {
          await analytics.track(
            SurfaceContentLoadedEvent(
              surface: AnalyticsSurfaceValue.homeWallpaperGrid,
              result: EventResultValue.success,
              loadTimeMs: loadTimeMs,
              sourceContext: 'home_wallpaper_grid_initial',
              itemCount: itemCount,
            ),
          );
        },
      );
    }
    Map<String, dynamic>? wallAt(int index) {
      if (index < 0 || index >= subWalls.length) {
        return null;
      }
      final dynamic wall = subWalls[index];
      if (wall is Map<String, dynamic>) {
        return wall;
      }
      if (wall is Map) {
        return wall.cast<String, dynamic>();
      }
      return null;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 5.0),
      child: NestedScrollView(
        controller: controller,
        headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
          SliverAppBar(
            primary: false,
            backgroundColor: Theme.of(context).primaryColor,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            expandedHeight: 200,
            flexibleSpace: SizedBox(
              child: Stack(
                alignment: AlignmentDirectional.bottomEnd,
                children: <Widget>[
                  CarouselSlider.builder(
                    carouselController: carouselController,
                    itemCount: 5,
                    options: CarouselOptions(
                      height: 200,
                      autoPlay: true,
                      autoPlayInterval: const Duration(seconds: 3),
                      onPageChanged: (index, reason) {
                        if (mounted) {
                          setState(() {
                            _current = index;
                          });
                        }
                      },
                    ),
                    itemBuilder: (BuildContext context, int i, int rI) {
                      if (i == 4) {
                        return Container(
                          width: MediaQuery.of(context).size.width,
                          margin: const EdgeInsets.fromLTRB(3, 1, 3, 6),
                          child: GestureDetector(
                            onTap: () {
                              unawaited(
                                analytics.track(
                                  SurfaceActionTappedEvent(
                                    surface: AnalyticsSurfaceValue.homeWallpaperGrid,
                                    action: AnalyticsActionValue.bannerTapped,
                                    sourceContext: 'home_wallpaper_grid_banner',
                                  ),
                                ),
                              );
                              launch(app_state.bannerURL);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: context.prismModeStyleForContext() == "Dark"
                                    ? Colors.white10
                                    : Colors.black.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(20),
                                image: DecorationImage(
                                  image: CachedNetworkImageProvider(app_state.topImageLink),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: MediaQuery.of(context).size.width,
                                  color: app_state.bannerTextOn
                                      ? Colors.black.withValues(alpha: 0.4)
                                      : Colors.transparent,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      app_state.bannerTextOn ? app_state.bannerText.toUpperCase() : "",
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      style: Theme.of(context).textTheme.displayMedium!.copyWith(
                                        fontSize: 20,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      final Map<String, dynamic>? wall = wallAt(i);
                      return Container(
                        width: MediaQuery.of(context).size.width,
                        margin: const EdgeInsets.fromLTRB(3, 1, 3, 6),
                        child: GestureDetector(
                          onTap: () {
                            if (wall == null) {
                              return;
                            }
                            unawaited(
                              analytics.track(
                                SurfaceActionTappedEvent(
                                  surface: AnalyticsSurfaceValue.homeWallpaperGrid,
                                  action: AnalyticsActionValue.carouselItemOpened,
                                  sourceContext: 'home_wallpaper_grid_carousel',
                                  itemType: ItemTypeValue.wallpaper,
                                  itemId: wall["id"]?.toString(),
                                  index: i,
                                ),
                              ),
                            );
                            context.router.push(
                              WallpaperRoute(arguments: [widget.provider, i, wall["wallpaper_thumb"]]),
                            );
                          },
                          child: wall == null
                              ? Container(
                                  decoration: BoxDecoration(
                                    color: context.prismModeStyleForContext() == "Dark"
                                        ? Colors.white10
                                        : Colors.black.withValues(alpha: .1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                )
                              : PremiumBannerWallsCarousel(
                                  comparator: !app_state.isPremiumWall(
                                    app_state.premiumCollections,
                                    wall["collections"] as List? ?? [],
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: context.prismModeStyleForContext() == "Dark"
                                          ? Colors.white10
                                          : Colors.black.withValues(alpha: .1),
                                      borderRadius: BorderRadius.circular(20),
                                      image: DecorationImage(
                                        image: CachedNetworkImageProvider(wall["wallpaper_thumb"].toString()),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: MediaQuery.of(context).size.width,
                                        color: Colors.transparent,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "",
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            style: Theme.of(context).textTheme.displayMedium!.copyWith(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  CarouselDots(current: _current),
                ],
              ),
            ),
          ),
        ],
        body: RefreshIndicator(
          backgroundColor: Theme.of(context).primaryColor,
          key: refreshHomeKey,
          onRefresh: refreshList,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              _scrollMilestoneTracker.onScroll(
                metrics: scrollInfo.metrics,
                itemCount: subWalls.length,
                onMilestoneReached: (depth, {required int itemCount}) async {
                  await analytics.track(
                    ScrollMilestoneReachedEvent(
                      surface: AnalyticsSurfaceValue.homeWallpaperGrid,
                      listName: ScrollListNameValue.wallpaperGrid,
                      depth: depth,
                      sourceContext: 'home_wallpaper_grid_scroll',
                      itemCount: itemCount,
                    ),
                  );
                },
              );
              if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                unawaited(_triggerSeeMore(subWalls));
              }
              return false;
            },
            child: GridView.builder(
              physics: const ScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(5, 0, 5, 4),
              itemCount: subWalls.isEmpty
                  ? 20
                  : subWalls.length > 4
                  ? subWalls.length - 4
                  : 0,
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
                childAspectRatio: 0.6625,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                if (subWalls.isEmpty) {
                  return Container(
                    decoration: BoxDecoration(
                      color: context.prismModeStyleForContext() == "Dark"
                          ? Colors.white10
                          : Colors.black.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }

                index = index + 4;
                if (index >= subWalls.length) {
                  return const SizedBox.shrink();
                }
                if (index == subWalls.length - 1 && Data.prismHasMore) {
                  return SeeMoreButton(
                    seeMoreLoader: seeMoreLoader,
                    func: () {
                      unawaited(
                        analytics.track(
                          SurfaceActionTappedEvent(
                            surface: AnalyticsSurfaceValue.homeWallpaperGrid,
                            action: AnalyticsActionValue.seeMoreTapped,
                            sourceContext: 'home_wallpaper_grid_see_more',
                          ),
                        ),
                      );
                      unawaited(_triggerSeeMore(subWalls));
                    },
                  );
                }
                return app_state.prismUser.premium == true
                    ? FocusedMenuHolder(
                        provider: widget.provider,
                        index: index,
                        child: WallpaperTile(widget: widget, index: index),
                      )
                    : PremiumBannerWalls(
                        comparator: !app_state.isPremiumWall(
                          app_state.premiumCollections,
                          wallAt(index)?["collections"] as List? ?? [],
                        ),
                        defaultChild: FocusedMenuHolder(
                          provider: widget.provider,
                          index: index,
                          child: WallpaperTile(widget: widget, index: index),
                        ),
                        trueChild: WallpaperTile(widget: widget, index: index),
                      );
              },
            ),
          ),
        ),
      ),
    );
  }
}
