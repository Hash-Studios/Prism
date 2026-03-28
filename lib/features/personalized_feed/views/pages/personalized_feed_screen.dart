import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/home/wallpapers/carouselDots.dart';
import 'package:Prism/core/widgets/premiumBanners/wallsCarousel.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/views/widgets/empty_card.dart';
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

class _PersonalizedFeedScreenState extends State<PersonalizedFeedScreen> with AutomaticKeepAliveClientMixin {
  static const int _carouselPreviewCount = 4;

  late final PersonalizedFeedBloc _bloc;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<PersonalizedFeedBloc>();
    _bloc.add(const PersonalizedFeedEvent.started());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _maybeFetchMore(ScrollMetrics metrics) {
    if (metrics.maxScrollExtent <= 0) {
      return;
    }
    final state = _bloc.state;
    if (state.isFetchingMore || !state.hasMore || state.status == LoadStatus.loading) {
      return;
    }

    if (metrics.pixels >= metrics.maxScrollExtent - 400) {
      _bloc.add(const PersonalizedFeedEvent.fetchMoreRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<PersonalizedFeedBloc, PersonalizedFeedState>(
        buildWhen: (prev, curr) =>
            prev.status != curr.status ||
            prev.items.length != curr.items.length ||
            prev.isFetchingMore != curr.isFetchingMore ||
            prev.hasMore != curr.hasMore,
        builder: (context, state) {
          final theme = Theme.of(context);
          final visibleItems = _gridItemsWithoutCarouselPreview(state);
          final previewWalls = state.items
              .whereType<PrismFeedItem>()
              .take(_carouselPreviewCount)
              .toList(growable: false);
          final crossAxisCount = MediaQuery.of(context).orientation == Orientation.portrait ? 3 : 5;
          final tileMemCacheHeight = ((MediaQuery.sizeOf(context).width / crossAxisCount) * 1.5 * 2).toInt();

          if (state.status == LoadStatus.initial || (state.status == LoadStatus.loading && state.items.isEmpty)) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (state.status == LoadStatus.failure && state.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _bloc.add(const PersonalizedFeedEvent.refreshRequested()),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 120, 24, 32),
                children: [
                  PersonalizedFeedEditorialNote(
                    title: "Couldn't load your feed",
                    detail: 'Check your connection, then pull down to try again.',
                    accentColor: theme.colorScheme.error,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _bloc.add(const PersonalizedFeedEvent.refreshRequested()),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.depth == 0) {
                  _maybeFetchMore(notification.metrics);
                }
                return false;
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // Carousel: WallOfTheDay + banner + 4 wallpaper previews
                  SliverToBoxAdapter(child: _FeedCarousel(previewWalls: previewWalls)),
                  SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.5,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => WallpaperTile(
                        item: visibleItems[index],
                        index: index,
                        crossAxisCount: crossAxisCount,
                        memCacheHeight: tileMemCacheHeight,
                      ),
                      childCount: visibleItems.length,
                    ),
                  ),
                  SliverToBoxAdapter(child: _bottomState(context, state)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _bottomState(BuildContext context, PersonalizedFeedState state) {
    if (state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: PersonalizedEmptyCard(
          title: 'Shape this feed',
          detail: 'Follow creators or choose interests so we can surface more of what you like.',
        ),
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
      padding: EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: PersonalizedEmptyCard(
        title: "You're caught up",
        detail: 'Pull down to refresh — new picks will land here.',
      ),
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

class _FeedCarousel extends StatefulWidget {
  const _FeedCarousel({required this.previewWalls});

  final List<PrismFeedItem> previewWalls;

  @override
  State<_FeedCarousel> createState() => _FeedCarouselState();
}

class _FeedCarouselState extends State<_FeedCarousel> {
  int _current = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    final previewWalls = widget.previewWalls;
    final height = MediaQuery.of(context).size.width * 2 / 3;
    return SizedBox(
      height: height,
      child: Stack(
        alignment: AlignmentDirectional.bottomEnd,
        children: [
          CarouselSlider.builder(
            carouselController: _carouselController,
            itemCount: 6,
            options: CarouselOptions(
              height: height,
              viewportFraction: 1.0,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 5),
              onPageChanged: (index, reason) {
                if (mounted) setState(() => _current = index);
              },
            ),
            itemBuilder: (BuildContext context, int i, int rI) {
              if (i == 0) {
                return const SizedBox.expand(child: WallOfTheDayCard());
              }
              if (i == 1) {
                return GestureDetector(
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
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(app_state.topImageLink),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Center(
                      child: ColoredBox(
                        color: app_state.bannerTextOn
                            ? Theme.of(context).colorScheme.scrim.withValues(alpha: 0.45)
                            : Colors.transparent,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            app_state.bannerTextOn ? app_state.bannerText.toUpperCase() : "",
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.displayMedium!.copyWith(
                              fontSize: 20,
                              // High-contrast on arbitrary photography under [ColorScheme.scrim].
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
              return GestureDetector(
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
                  context.router.push(WallpaperDetailRoute(entity: WallpaperDetailEntityX.fromFeedItem(wall)));
                },
                child: wall == null
                    ? ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest)
                    : PremiumBannerWallsCarousel(
                        comparator: !app_state.isPremiumWall(
                          app_state.premiumCollections,
                          wall.wallpaper.collections ?? const <String>[],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            image: DecorationImage(
                              image: CachedNetworkImageProvider(wall.wallpaper.thumbnailUrl),
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
    );
  }
}
