import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_action_payload.dart';
import 'package:Prism/core/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_view.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FavouriteGrid extends StatefulWidget {
  const FavouriteGrid({super.key});

  @override
  _FavouriteGridState createState() => _FavouriteGridState();
}

class _FavouriteGridState extends State<FavouriteGrid> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<Color?> animation;
  GlobalKey<RefreshIndicatorState> refreshFavKey = GlobalKey<RefreshIndicatorState>();
  final ScrollMilestoneTracker _scrollMilestoneTracker = ScrollMilestoneTracker();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();

  @override
  void initState() {
    super.initState();
    _contentLoadTracker.start();
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
    super.dispose();
  }

  Future<void> refreshList() async {
    refreshFavKey.currentState?.show();
    _contentLoadTracker.start();
    _scrollMilestoneTracker.reset();
    await context.favouriteWallsAdapter(listen: false).getDataBase(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final likedWalls = context.favouriteWallsAdapter(listen: false).liked;
    if (likedWalls != null) {
      _contentLoadTracker.success(
        itemCount: likedWalls.length,
        onSuccess: ({required int loadTimeMs, int? itemCount}) async {
          await analytics.track(
            SurfaceContentLoadedEvent(
              surface: AnalyticsSurfaceValue.favouriteWallsGrid,
              result: (itemCount ?? 0) > 0 ? EventResultValue.success : EventResultValue.empty,
              loadTimeMs: loadTimeMs,
              sourceContext: 'favourite_walls_grid_initial',
              itemCount: itemCount,
            ),
          );
        },
      );
    }
    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
      key: refreshFavKey,
      onRefresh: refreshList,
      child: context.favouriteWallsAdapter(listen: false).liked != null
          ? context.favouriteWallsAdapter(listen: false).liked!.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        child: context.prismModeStyleForContext() == "Dark"
                            ? SvgPicture.string(
                                favouritesDark
                                    .replaceAll(
                                      "181818",
                                      Theme.of(context).primaryColor.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "E57697",
                                      Theme.of(
                                        context,
                                      ).colorScheme.error.toString().replaceAll("Color(0xff", "").replaceAll(")", ""),
                                    )
                                    .replaceAll(
                                      "F0F0F0",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "2F2E41",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "3F3D56",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "2F2F2F",
                                      Theme.of(context).hintColor.toARGB32().toRadixString(16).substring(2),
                                    ),
                              )
                            : SvgPicture.string(
                                favouritesLight
                                    .replaceAll(
                                      "181818",
                                      Theme.of(context).primaryColor.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "E57697",
                                      Theme.of(
                                        context,
                                      ).colorScheme.error.toString().replaceAll("Color(0xff", "").replaceAll(")", ""),
                                    )
                                    .replaceAll(
                                      "F0F0F0",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "2F2E41",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "3F3D56",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "2F2F2F",
                                      Theme.of(context).hintColor.toARGB32().toRadixString(16).substring(2),
                                    ),
                              ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height * 0.1,
                      ),
                    ],
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification notification) {
                      _scrollMilestoneTracker.onScroll(
                        metrics: notification.metrics,
                        itemCount: context.favouriteWallsAdapter().liked!.length,
                        onMilestoneReached: (depth, {required int itemCount}) async {
                          await analytics.track(
                            ScrollMilestoneReachedEvent(
                              surface: AnalyticsSurfaceValue.favouriteWallsGrid,
                              listName: ScrollListNameValue.favouriteWallsGrid,
                              depth: depth,
                              sourceContext: 'favourite_walls_grid_scroll',
                              itemCount: itemCount,
                            ),
                          );
                        },
                      );
                      return false;
                    },
                    child: GridView.builder(
                      shrinkWrap: true,
                      cacheExtent: 50000,
                      padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
                      itemCount: context.favouriteWallsAdapter().liked!.length,
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
                        childAspectRatio: 0.6625,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemBuilder: (context, index) {
                        final likedWall = context.favouriteWallsAdapter().liked![index];
                        final isWallhaven = likedWall.provider == 'WallHaven';
                        final isPrism = likedWall.provider == 'Prism';
                        final isPexels = likedWall.provider == 'Pexels';
                        final category = likedWall.category.trim();
                        final photographer = likedWall.photographer.trim();
                        final payload = WallpaperActionPayload(
                          providerLabel: 'Liked',
                          title: isWallhaven
                              ? (category.isEmpty
                                    ? 'Wallhaven'
                                    : '${category[0].toUpperCase()}${category.substring(1)}')
                              : (photographer.isEmpty ? 'Pexels' : photographer),
                          subtitle: likedWall.id.toUpperCase(),
                          stats: [
                            if (isWallhaven)
                              WallpaperActionStat(
                                kind: WallpaperActionStatKind.views,
                                label: 'Views: ${likedWall.views.isEmpty ? '0' : likedWall.views}',
                              ),
                            if (isPrism)
                              WallpaperActionStat(
                                kind: WallpaperActionStatKind.size,
                                label: likedWall.size.isEmpty ? '0' : likedWall.size,
                              ),
                            WallpaperActionStat(
                              kind: WallpaperActionStatKind.resolution,
                              label: likedWall.resolution.isEmpty ? '-' : likedWall.resolution,
                            ),
                          ],
                          fullUrl: likedWall.url,
                          favouriteWall: likedWall,
                          favouriteTrash: true,
                          cardTopFactor: isPexels ? 1 / 2 : 2 / 8,
                          cardHeightFactor: isPexels ? 1 / 2 : 6 / 8,
                          sourceContext: 'focused_menu.Liked',
                          contentId: likedWall.id,
                        );
                        return FocusedMenuHolder.payload(
                          payload: payload,
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: animation.value,
                                  borderRadius: BorderRadius.circular(20),
                                  image: DecorationImage(
                                    image: CachedNetworkImageProvider(likedWall.thumb),
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
                                      if (context.favouriteWallsAdapter(listen: false).liked == null ||
                                          context.favouriteWallsAdapter(listen: false).liked!.isEmpty) {
                                      } else {
                                        unawaited(
                                          analytics.track(
                                            SurfaceActionTappedEvent(
                                              surface: AnalyticsSurfaceValue.favouriteWallsGrid,
                                              action: AnalyticsActionValue.tileOpened,
                                              sourceContext: 'favourite_walls_grid_tile',
                                              itemType: ItemTypeValue.wallpaper,
                                              itemId: likedWall.id,
                                              index: index,
                                            ),
                                          ),
                                        );
                                        context.router.push(
                                          FavWallpaperViewRoute(
                                            wallIndex: index,
                                            thumbnailUrl: context
                                                .favouriteWallsAdapter(listen: false)
                                                .liked![index]
                                                .thumb,
                                          ),
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
                  )
          : const LoadingCards(),
    );
  }
}
