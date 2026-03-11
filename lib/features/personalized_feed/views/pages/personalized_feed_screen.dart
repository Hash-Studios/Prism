import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/core/wallpaper/wallpaper_action_payload.dart';
import 'package:Prism/core/widgets/home/wallpapers/carouselDots.dart';
import 'package:Prism/core/widgets/premiumBanners/wallsCarousel.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/pexels_tile.dart';
import 'package:Prism/features/category_feed/views/widgets/wallhaven_tile.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/views/widgets/animated_feed_tile.dart';
import 'package:Prism/features/personalized_feed/views/widgets/empty_card.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/features/wall_of_the_day/wall_of_the_day.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PersonalizedFeedScreen extends StatefulWidget {
  const PersonalizedFeedScreen({super.key});

  @override
  State<PersonalizedFeedScreen> createState() => _PersonalizedFeedScreenState();
}

class _PersonalizedFeedScreenState extends State<PersonalizedFeedScreen> {
  static const int _carouselPreviewCount = 4;

  late final PersonalizedFeedBloc _bloc;
  final ScrollController _scrollController = ScrollController();
  int _current = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();

  @override
  void initState() {
    super.initState();
    _bloc = getIt<PersonalizedFeedBloc>();
    _scrollController.addListener(_onScroll);
    _bloc.add(const PersonalizedFeedEvent.started());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final state = _bloc.state;
    if (state.isFetchingMore || !state.hasMore || state.status == LoadStatus.loading) {
      return;
    }

    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      _bloc.add(const PersonalizedFeedEvent.fetchMoreRequested());
    }
  }

  Widget _buildCarousel(BuildContext context, PersonalizedFeedState state) {
    final List<PrismFeedItem> previewWalls = state.items
        .whereType<PrismFeedItem>()
        .take(_carouselPreviewCount)
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 200,
        child: Stack(
          alignment: AlignmentDirectional.bottomEnd,
          children: [
            CarouselSlider.builder(
              carouselController: _carouselController,
              itemCount: 6,
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
                if (i == 0) {
                  return Container(
                    width: MediaQuery.of(context).size.width,
                    margin: const EdgeInsets.fromLTRB(3, 1, 3, 6),
                    child: const WallOfTheDayCard(),
                  );
                }
                if (i == 1) {
                  return Container(
                    width: MediaQuery.of(context).size.width,
                    margin: const EdgeInsets.fromLTRB(3, 1, 3, 6),
                    child: GestureDetector(
                      onTap: () {
                        unawaited(
                          analytics.track(
                            const SurfaceActionTappedEvent(
                              surface: AnalyticsSurfaceValue.homeWallpaperGrid,
                              action: AnalyticsActionValue.bannerTapped,
                              sourceContext: 'personalized_feed_carousel_banner',
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
                            color: app_state.bannerTextOn ? Colors.black.withValues(alpha: 0.4) : Colors.transparent,
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
                final int feedIndex = i - 2;
                final PrismFeedItem? wall = feedIndex >= 0 && feedIndex < previewWalls.length
                    ? previewWalls[feedIndex]
                    : null;
                return Container(
                  width: MediaQuery.of(context).size.width,
                  margin: const EdgeInsets.fromLTRB(3, 1, 3, 6),
                  child: GestureDetector(
                    onTap: () {
                      if (wall == null) return;
                      unawaited(
                        analytics.track(
                          SurfaceActionTappedEvent(
                            surface: AnalyticsSurfaceValue.homeWallpaperGrid,
                            action: AnalyticsActionValue.carouselItemOpened,
                            sourceContext: 'personalized_feed_carousel',
                            itemType: ItemTypeValue.wallpaper,
                            itemId: wall.id,
                            index: feedIndex,
                          ),
                        ),
                      );
                      context.router.push(
                        WallpaperRoute(
                          source: WallpaperSource.prism,
                          index: feedIndex,
                          link: wall.wallpaper.thumbnailUrl,
                          item: wall,
                        ),
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
                              wall.wallpaper.collections ?? const <String>[],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: context.prismModeStyleForContext() == "Dark"
                                    ? Colors.white10
                                    : Colors.black.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(20),
                                image: DecorationImage(
                                  image: CachedNetworkImageProvider(wall.wallpaper.thumbnailUrl),
                                  fit: BoxFit.cover,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocConsumer<PersonalizedFeedBloc, PersonalizedFeedState>(
        listener: (_, __) {},
        builder: (context, state) {
          final theme = Theme.of(context);
          final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
          final visibleItems = _gridItemsWithoutCarouselPreview(state);

          if (state.status == LoadStatus.initial || (state.status == LoadStatus.loading && state.items.isEmpty)) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (state.status == LoadStatus.failure && state.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _bloc.add(const PersonalizedFeedEvent.refreshRequested()),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.14)),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.wifi_tethering_error_rounded, size: 28),
                        SizedBox(height: 10),
                        Text("Couldn't load your personalized feed."),
                        SizedBox(height: 6),
                        Text('Pull down to retry.'),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _bloc.add(const PersonalizedFeedEvent.refreshRequested()),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                // Carousel: WallOfTheDay + banner + 4 wallpaper previews
                SliverToBoxAdapter(child: _buildCarousel(context, state)),
                // SliverToBoxAdapter(
                //   child: AnimatedOpacity(
                //     opacity: state.status == LoadStatus.success ? 1 : 0,
                //     duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
                //     curve: Curves.easeOut,
                //     child: AnimatedSlide(
                //       offset: state.status == LoadStatus.success ? Offset.zero : const Offset(0, 0.06),
                //       duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
                //       curve: Curves.easeOutCubic,
                //       child: PersonalizedFeedHeader(
                //         prismCount: state.sourcePrism,
                //         wallhavenCount: state.sourceWallhaven,
                //         pexelsCount: state.sourcePexels,
                //         itemCount: state.items.length,
                //         isFetchingMore: state.isFetchingMore,
                //       ),
                //     ),
                //   ),
                // ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
                      childAspectRatio: 0.6625,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = visibleItems[index];
                      final tile = switch (item) {
                        PrismFeedItem prism => WallpaperTile(item: prism, index: index),
                        WallhavenFeedItem wallhaven => WallhavenTile(item: wallhaven, index: index),
                        PexelsFeedItem pexels => PexelsTile(item: pexels, index: index),
                      };

                      final payload = WallpaperActionPayloadAdapter.fromFeedItem(
                        item,
                        sourceContext: 'focused_menu.personalized_feed.${item.source.wireValue}',
                      );

                      return AnimatedFeedTile(
                        index: index,
                        reduceMotion: reduceMotion,
                        child: FocusedMenuHolder.payload(payload: payload, child: tile),
                      );
                    }, childCount: visibleItems.length),
                  ),
                ),
                SliverToBoxAdapter(child: _bottomState(context, state)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _bottomState(BuildContext context, PersonalizedFeedState state) {
    if (state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 26),
        child: PersonalizedEmptyCard(message: 'Follow more creators or pick interests to improve your For You feed.'),
      );
    }

    if (state.isFetchingMore) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(0, 8, 0, 26),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }

    if (state.hasMore) {
      return const SizedBox(height: 22);
    }

    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 26),
      child: PersonalizedEmptyCard(message: 'You are all caught up. Pull to refresh for fresh picks.'),
    );
  }

  List<FeedItemEntity> _gridItemsWithoutCarouselPreview(PersonalizedFeedState state) {
    var skippedPrismCount = 0;
    return state.items
        .where((item) {
          if (item is PrismFeedItem && skippedPrismCount < _carouselPreviewCount) {
            skippedPrismCount += 1;
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }
}
