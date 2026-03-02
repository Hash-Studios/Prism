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
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as PData;
import 'package:Prism/features/category_feed/views/category_feed_bloc_adapter.dart';
import 'package:Prism/features/category_feed/views/widgets/pexels_tile.dart';
import 'package:Prism/features/navigation/views/widgets/inherited_scroll_controller_provider.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

class PexelsGrid extends StatefulWidget {
  final String? provider;
  const PexelsGrid({required this.provider});
  @override
  _PexelsGridState createState() => _PexelsGridState();
}

class _PexelsGridState extends State<PexelsGrid> {
  int _current = 0;
  GlobalKey<RefreshIndicatorState> refreshHomeKey = GlobalKey<RefreshIndicatorState>();

  bool seeMoreLoader = false;
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
    PData.wallsP = [];
    await context.categoryChangeWallpaperFuture(context.categorySelectedChoice(listen: false), "r");
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController? controller = InheritedDataProvider.of(context)!.scrollController;
    final CarouselSliderController carouselController = CarouselSliderController();
    if (PData.wallsP.isNotEmpty) {
      _contentLoadTracker.success(
        itemCount: PData.wallsP.length,
        onSuccess: ({required int loadTimeMs, int? itemCount}) async {
          await analytics.track(
            SurfaceContentLoadedEvent(
              surface: AnalyticsSurfaceValue.homePexelsGrid,
              result: EventResultValue.success,
              loadTimeMs: loadTimeMs,
              sourceContext: 'home_pexels_grid_initial',
              itemCount: itemCount,
            ),
          );
        },
      );
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
                    itemBuilder: (BuildContext context, int i, int rI) => i == 4
                        ? Container(
                            width: MediaQuery.of(context).size.width,
                            margin: const EdgeInsets.fromLTRB(5, 1, 5, 7),
                            child: GestureDetector(
                              onTap: () {
                                unawaited(
                                  analytics.track(
                                    SurfaceActionTappedEvent(
                                      surface: AnalyticsSurfaceValue.homePexelsGrid,
                                      action: AnalyticsActionValue.bannerTapped,
                                      sourceContext: 'home_pexels_grid_banner',
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
                          )
                        : Container(
                            width: MediaQuery.of(context).size.width,
                            margin: const EdgeInsets.fromLTRB(5, 1, 5, 7),
                            child: GestureDetector(
                              onTap: () {
                                if (PData.wallsP == []) {
                                } else {
                                  unawaited(
                                    analytics.track(
                                      SurfaceActionTappedEvent(
                                        surface: AnalyticsSurfaceValue.homePexelsGrid,
                                        action: AnalyticsActionValue.carouselItemOpened,
                                        sourceContext: 'home_pexels_grid_carousel',
                                        itemType: ItemTypeValue.wallpaper,
                                        itemId: PData.wallsP[i].id.toString(),
                                        index: i,
                                      ),
                                    ),
                                  );
                                  context.router.push(
                                    WallpaperRoute(
                                      provider: widget.provider.toString(),
                                      index: i,
                                      link: PData.wallsP[i].src!["small"].toString(),
                                    ),
                                  );
                                }
                              },
                              child: PData.wallsP.isEmpty
                                  ? Container(
                                      decoration: BoxDecoration(
                                        color: context.prismModeStyleForContext() == "Dark"
                                            ? Colors.white10
                                            : Colors.black.withValues(alpha: .1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: context.prismModeStyleForContext() == "Dark"
                                            ? Colors.white10
                                            : Colors.black.withValues(alpha: .1),
                                        borderRadius: BorderRadius.circular(20),
                                        image: DecorationImage(
                                          image: CachedNetworkImageProvider(PData.wallsP[i].src!["medium"].toString()),
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
                itemCount: PData.wallsP.length,
                onMilestoneReached: (depth, {required int itemCount}) async {
                  await analytics.track(
                    ScrollMilestoneReachedEvent(
                      surface: AnalyticsSurfaceValue.homePexelsGrid,
                      listName: ScrollListNameValue.pexelsGrid,
                      depth: depth,
                      sourceContext: 'home_pexels_grid_scroll',
                      itemCount: itemCount,
                    ),
                  );
                },
              );
              if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                if (!seeMoreLoader) {
                  context.categoryChangeWallpaperFuture(context.categorySelectedChoice(listen: false), "s");
                  setState(() {
                    seeMoreLoader = true;
                    Future.delayed(const Duration(seconds: 2)).then((value) => seeMoreLoader = false);
                  });
                }
              }
              return false;
            },
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(5, 0, 5, 4),
              itemCount: PData.wallsP.isEmpty ? 20 : PData.wallsP.length - 4,
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
                childAspectRatio: 0.6625,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                index = index + 4;
                if (index == PData.wallsP.length - 1) {
                  return SeeMoreButton(
                    seeMoreLoader: seeMoreLoader,
                    func: () {
                      unawaited(
                        analytics.track(
                          SurfaceActionTappedEvent(
                            surface: AnalyticsSurfaceValue.homePexelsGrid,
                            action: AnalyticsActionValue.seeMoreTapped,
                            sourceContext: 'home_pexels_grid_see_more',
                          ),
                        ),
                      );
                      if (!seeMoreLoader) {
                        context.categoryChangeWallpaperFuture(context.categorySelectedChoice(listen: false), "s");
                        setState(() {
                          seeMoreLoader = true;
                          Future.delayed(const Duration(seconds: 2)).then((value) => seeMoreLoader = false);
                        });
                      }
                    },
                  );
                }

                return FocusedMenuHolder(
                  provider: widget.provider,
                  index: index,
                  child: PexelsTile(widget: widget, index: index),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
