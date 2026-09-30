import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/favourite_setups/views/favourite_setups_bloc_adapter.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:Prism/global/svg_assets.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FavouriteSetupGrid extends StatefulWidget {
  const FavouriteSetupGrid({super.key});

  @override
  State<FavouriteSetupGrid> createState() => _FavouriteSetupGridState();
}

class _FavouriteSetupGridState extends State<FavouriteSetupGrid> {
  final ScrollMilestoneTracker _scrollMilestoneTracker = ScrollMilestoneTracker();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();
  late final Future<void> _initialLoad;

  @override
  void initState() {
    super.initState();
    _contentLoadTracker.start();
    _initialLoad = context.favouriteSetupsAdapter(listen: false).load();
  }

  Future<void> _refresh() {
    _contentLoadTracker.start();
    _scrollMilestoneTracker.reset();
    return context.favouriteSetupsAdapter(listen: false).load();
  }

  @override
  Widget build(BuildContext context) {
    final List<SetupEntity>? setups = context.favouriteSetupsAdapter().items;
    return FutureBuilder<void>(
      future: _initialLoad,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || setups == null) {
          return const LoadingCards(childAspectRatio: 0.5025, borderRadius: BorderRadius.all(Radius.circular(20)));
        }
        _contentLoadTracker.success(
          itemCount: setups.length,
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
        return RefreshIndicator(
          backgroundColor: Theme.of(context).primaryColor,
          onRefresh: _refresh,
          child: setups.isEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: SvgPicture.string(
                        themedIllustration(context, dark: favouritesDark, light: favouritesLight),
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
                      itemCount: setups.length,
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
                    scrollCacheExtent: const ScrollCacheExtent.pixels(50000),
                    padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
                    itemCount: setups.length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
                      childAspectRatio: 0.5025,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          PrismImageTile(url: setups[index].image, borderRadius: BorderRadius.circular(20)),
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
                                        surface: AnalyticsSurfaceValue.favouriteSetupsGrid,
                                        action: AnalyticsActionValue.tileOpened,
                                        sourceContext: 'favourite_setups_grid_tile',
                                        itemId: setups[index].id,
                                        index: index,
                                      ),
                                    ),
                                  );
                                  context.router.push(FavSetupViewRoute(setupIndex: index));
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}
