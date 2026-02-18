import 'dart:async';

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
import 'package:Prism/global/globals.dart' as globals;
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
  @override
  void initState() {
    super.initState();
  }

  Future<void> refreshList() async {
    refreshHomeKey.currentState?.show();
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
                              launch(globals.bannerURL);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: context.prismModeStyleForContext() == "Dark"
                                    ? Colors.white10
                                    : Colors.black.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(20),
                                image: DecorationImage(
                                  image: CachedNetworkImageProvider(globals.topImageLink),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: MediaQuery.of(context).size.width,
                                  color: globals.bannerTextOn == "true"
                                      ? Colors.black.withValues(alpha: 0.4)
                                      : Colors.transparent,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      globals.bannerTextOn == "true" ? globals.bannerText.toUpperCase() : "",
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
                                  comparator: !globals.isPremiumWall(
                                    globals.premiumCollections,
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
                      unawaited(_triggerSeeMore(subWalls));
                    },
                  );
                }
                return globals.prismUser.premium == true
                    ? FocusedMenuHolder(
                        provider: widget.provider,
                        index: index,
                        child: WallpaperTile(widget: widget, index: index),
                      )
                    : PremiumBannerWalls(
                        comparator: !globals.isPremiumWall(
                          globals.premiumCollections,
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
