import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/home/wallpapers/carouselDots.dart';
import 'package:Prism/core/widgets/home/wallpapers/seeMoreButton.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/category_feed_bloc_adapter.dart';
import 'package:Prism/features/category_feed/views/widgets/pexels_tile.dart';
import 'package:Prism/features/navigation/views/widgets/inherited_scroll_controller_provider.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PexelsGrid extends StatefulWidget {
  const PexelsGrid({super.key});

  @override
  State<PexelsGrid> createState() => _PexelsGridState();
}

class _PexelsGridState extends State<PexelsGrid> {
  int _current = 0;
  final GlobalKey<RefreshIndicatorState> refreshHomeKey = GlobalKey<RefreshIndicatorState>();
  final ScrollMilestoneTracker _scrollMilestoneTracker = ScrollMilestoneTracker();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();
  bool seeMoreLoader = false;

  @override
  void initState() {
    super.initState();
    _contentLoadTracker.start();
  }

  Future<void> refreshList() async {
    refreshHomeKey.currentState?.show();
    _contentLoadTracker.start();
    _scrollMilestoneTracker.reset();
    await context.categoryChangeWallpaperFuture(context.categorySelectedChoice(listen: false), "r");
  }

  Future<void> _triggerSeeMore({required bool hasMore, required int itemCount}) async {
    if (seeMoreLoader || !hasMore) {
      return;
    }
    setState(() {
      seeMoreLoader = true;
    });
    try {
      await context.categoryChangeWallpaperFuture(context.categorySelectedChoice(listen: false), "s");
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
    final CategoryFeedState state = context.watch<CategoryFeedBloc>().state;
    final List<PexelsFeedItem> walls = state.items.whereType<PexelsFeedItem>().toList(growable: false);

    if (walls.isNotEmpty) {
      _contentLoadTracker.success(
        itemCount: walls.length,
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
                    itemBuilder: (BuildContext context, int i, int rI) {
                      if (i == 4) {
                        return Container(
                          width: MediaQuery.of(context).size.width,
                          margin: const EdgeInsets.fromLTRB(5, 1, 5, 7),
                          child: GestureDetector(
                            onTap: () {
                              unawaited(
                                analytics.track(
                                  const SurfaceActionTappedEvent(
                                    surface: AnalyticsSurfaceValue.homePexelsGrid,
                                    action: AnalyticsActionValue.bannerTapped,
                                    sourceContext: 'home_pexels_grid_banner',
                                  ),
                                ),
                              );
                              openPrismLink(context, app_state.bannerURL);
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
                      final PexelsFeedItem? item = i < walls.length ? walls[i] : null;
                      return Container(
                        width: MediaQuery.of(context).size.width,
                        margin: const EdgeInsets.fromLTRB(5, 1, 5, 7),
                        child: GestureDetector(
                          onTap: () {
                            if (item == null) {
                              return;
                            }
                            unawaited(
                              analytics.track(
                                SurfaceActionTappedEvent(
                                  surface: AnalyticsSurfaceValue.homePexelsGrid,
                                  action: AnalyticsActionValue.carouselItemOpened,
                                  sourceContext: 'home_pexels_grid_carousel',
                                  itemType: ItemTypeValue.wallpaper,
                                  itemId: item.id,
                                  index: i,
                                ),
                              ),
                            );
                            context.router.push(
                              WallpaperRoute(
                                source: WallpaperSource.pexels,
                                index: i,
                                link: item.wallpaper.thumbnailUrl,
                                item: item,
                              ),
                            );
                          },
                          child: item == null
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
                                      image: CachedNetworkImageProvider(item.wallpaper.thumbnailUrl),
                                      fit: BoxFit.cover,
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
                itemCount: walls.length,
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
                unawaited(_triggerSeeMore(hasMore: state.hasMore, itemCount: walls.length));
              }
              return false;
            },
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(5, 0, 5, 4),
              itemCount: walls.isEmpty
                  ? 20
                  : walls.length > 4
                  ? walls.length - 4
                  : 0,
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
                childAspectRatio: 0.6625,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                if (walls.isEmpty) {
                  return Container(
                    decoration: BoxDecoration(
                      color: context.prismModeStyleForContext() == "Dark"
                          ? Colors.white10
                          : Colors.black.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }
                final int itemIndex = index + 4;
                if (itemIndex == walls.length - 1) {
                  return SeeMoreButton(
                    seeMoreLoader: seeMoreLoader,
                    func: () {
                      unawaited(
                        analytics.track(
                          const SurfaceActionTappedEvent(
                            surface: AnalyticsSurfaceValue.homePexelsGrid,
                            action: AnalyticsActionValue.seeMoreTapped,
                            sourceContext: 'home_pexels_grid_see_more',
                          ),
                        ),
                      );
                      unawaited(_triggerSeeMore(hasMore: state.hasMore, itemCount: walls.length));
                    },
                  );
                }
                return PexelsTile(item: walls[itemIndex], index: itemIndex);
              },
            ),
          ),
        ),
      ),
    );
  }
}
