import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/favourite_setups/views/favourite_setups_bloc_adapter.dart';
import 'package:Prism/features/navigation/views/widgets/inherited_scroll_controller_provider.dart';
import 'package:Prism/features/setups/views/widgets/loading_setup_cards.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FavouriteSetupGrid extends StatefulWidget {
  const FavouriteSetupGrid({super.key});

  @override
  _FavouriteSetupGridState createState() => _FavouriteSetupGridState();
}

class _FavouriteSetupGridState extends State<FavouriteSetupGrid> with SingleTickerProviderStateMixin {
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
    context.favouriteSetupsAdapter(listen: false).getDataBase();
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController? controller = InheritedDataProvider.of(context)!.scrollController;
    final likedSetups = context.favouriteSetupsAdapter(listen: false).liked;
    if (likedSetups != null) {
      _contentLoadTracker.success(
        itemCount: likedSetups.length,
        onSuccess: ({required int loadTimeMs, int? itemCount}) async {
          await analytics.track(
            SurfaceContentLoadedEvent(
              surface: AnalyticsSurfaceValue.favouriteSetupsGrid,
              result: (itemCount ?? 0) > 0 ? EventResultValue.success : EventResultValue.empty,
              loadTimeMs: loadTimeMs,
              sourceContext: 'favourite_setups_grid_initial',
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
      child: context.favouriteSetupsAdapter(listen: false).liked != null
          ? context.favouriteSetupsAdapter(listen: false).liked!.isEmpty
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
                        itemCount: context.favouriteSetupsAdapter().liked!.length,
                        onMilestoneReached: (depth, {required int itemCount}) async {
                          await analytics.track(
                            ScrollMilestoneReachedEvent(
                              surface: AnalyticsSurfaceValue.favouriteSetupsGrid,
                              listName: ScrollListNameValue.favouriteSetupsGrid,
                              depth: depth,
                              sourceContext: 'favourite_setups_grid_scroll',
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
                      controller: controller,
                      itemCount: context.favouriteSetupsAdapter().liked!.length,
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
                        childAspectRatio: 0.5025,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: animation.value,
                                borderRadius: BorderRadius.circular(20),
                                image: DecorationImage(
                                  image: CachedNetworkImageProvider(
                                    context.favouriteSetupsAdapter().liked![index].image.toString(),
                                  ),
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
                                    if (context.favouriteSetupsAdapter(listen: false).liked == []) {
                                    } else {
                                      unawaited(
                                        analytics.track(
                                          SurfaceActionTappedEvent(
                                            surface: AnalyticsSurfaceValue.favouriteSetupsGrid,
                                            action: AnalyticsActionValue.tileOpened,
                                            sourceContext: 'favourite_setups_grid_tile',
                                            itemId: context
                                                .favouriteSetupsAdapter(listen: false)
                                                .liked![index]
                                                .id
                                                ?.toString(),
                                            index: index,
                                          ),
                                        ),
                                      );
                                      context.router.push(FavSetupViewRoute(setupIndex: index));
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  )
          : const LoadingSetupCards(),
    );
  }
}
