import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/premium_wall_utils.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/feed_scroll.dart';
import 'package:Prism/core/widgets/home/premium_corner_banner.dart';
import 'package:Prism/core/widgets/home/wallpapers/carousel_dots.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/following_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/popular_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/data/personalized_ranking_service.dart';
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:Prism/features/personalized_feed/views/widgets/empty_card.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_loading_more.dart';
import 'package:Prism/features/personalized_feed/views/widgets/home_chip_rail.dart';
import 'package:Prism/features/personalized_feed/views/widgets/paged_chip_sliver.dart';
import 'package:Prism/features/personalized_feed/views/widgets/prefetch_tiles.dart';
import 'package:Prism/features/prism_feed/biz/bloc/latest_feed_bloc.j.dart';
import 'package:Prism/features/prism_feed/biz/bloc/paged_feed_bloc.j.dart';
import 'package:Prism/features/session/data/low_data_mode.dart';
import 'package:Prism/features/wall_of_the_day/wall_of_the_day.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PersonalizedFeedScreen extends StatefulWidget {
  const PersonalizedFeedScreen({super.key, this.onTuneTap});

  final VoidCallback? onTuneTap;

  @override
  State<PersonalizedFeedScreen> createState() => _PersonalizedFeedScreenState();
}

class _PersonalizedFeedScreenState extends State<PersonalizedFeedScreen> with AutomaticKeepAliveClientMixin {
  static const int _carouselPreviewCount = PrismFeedLayout.carouselPreviewCount;

  late final PersonalizedFeedBloc _bloc;
  final ScrollController _scrollController = ScrollController();
  LatestFeedBloc? _latest;
  FollowingFeedBloc? _following;
  PopularFeedBloc? _popular;
  final Set<String> _knownItemIds = <String>{};

  @override
  bool get wantKeepAlive => true;

  /// Replaced by the Data saver setting once it exists.
  bool get _lowData => LowDataMode.enabled.value;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<PersonalizedFeedBloc>();
    personalizedFeedSettingsRevision.addListener(_onFeedSettingsChanged);
    _bloc.add(const PersonalizedFeedEvent.started());
  }

  void _onFeedSettingsChanged() {
    if (mounted) {
      _bloc.add(const PersonalizedFeedEvent.settingsChanged());
    }
  }

  @override
  void dispose() {
    personalizedFeedSettingsRevision.removeListener(_onFeedSettingsChanged);
    _scrollController.dispose();
    unawaited(_bloc.close());
    unawaited(_latest?.close());
    unawaited(_following?.close());
    unawaited(_popular?.close());
    super.dispose();
  }

  /// The list behind a chip other than For you. It loads the first time its chip is shown.
  PagedFeedBloc? _chipBloc(HomeFeedChip chip) => switch (chip) {
    HomeFeedChip.forYou => null,
    HomeFeedChip.latest => _latest ??= getIt<LatestFeedBloc>()..add(const PagedFeedEvent.started()),
    HomeFeedChip.following => _following ??= getIt<FollowingFeedBloc>()..add(const PagedFeedEvent.started()),
    HomeFeedChip.popular => _popular ??= getIt<PopularFeedBloc>()..add(const PagedFeedEvent.started()),
  };

  bool _showsSignIn(HomeFeedChip chip) => chip == HomeFeedChip.following && !app_state.prismUser.loggedIn;

  void _maybeFetchMore(ScrollMetrics metrics) {
    if (metrics.maxScrollExtent <= 0 || !isNearFeedEnd(metrics)) {
      return;
    }
    final HomeFeedChip chip = _bloc.state.chip;
    if (chip == HomeFeedChip.forYou) {
      final state = _bloc.state;
      if (!state.isFetchingMore &&
          state.hasMore &&
          state.status != LoadStatus.loading &&
          state.actionStatus != ActionStatus.failure) {
        _bloc.add(const PersonalizedFeedEvent.fetchMoreRequested());
      }
      return;
    }
    if (_showsSignIn(chip)) {
      return;
    }
    final PagedFeedBloc bloc = _chipBloc(chip)!;
    final PagedFeedState state = bloc.state;
    if (!state.isFetchingMore &&
        state.hasMore &&
        state.status != LoadStatus.loading &&
        state.actionStatus != ActionStatus.failure) {
      bloc.add(const PagedFeedEvent.fetchMoreRequested());
    }
  }

  /// Reloads the shown list and completes when the new items arrive, so the pull-to-refresh spinner lasts as long as
  /// the load.
  Future<void> _refresh() async {
    PrismHaptics.impact();
    final HomeFeedChip chip = _bloc.state.chip;
    if (chip != HomeFeedChip.forYou) {
      if (_showsSignIn(chip)) {
        return;
      }
      final PagedFeedBloc bloc = _chipBloc(chip)!;
      final Future<PagedFeedState> settled = bloc.stream.firstWhere((s) => s.status != LoadStatus.loading);
      bloc.add(const PagedFeedEvent.refreshRequested());
      await settled.timeout(const Duration(seconds: 30), onTimeout: () => bloc.state);
      return;
    }
    final Future<PersonalizedFeedState> settled = _bloc.stream.firstWhere((s) => s.status != LoadStatus.loading);
    _bloc.add(const PersonalizedFeedEvent.refreshRequested());
    final PersonalizedFeedState result = await settled.timeout(
      const Duration(seconds: 30),
      onTimeout: () => _bloc.state,
    );
    if (mounted && result.refreshFailed) {
      toasts.error("Couldn't refresh your feed.");
    }
  }

  void _lessLikeThis(FeedItemEntity item) {
    final int index = _bloc.state.items.indexOf(item);
    _bloc.add(PersonalizedFeedEvent.lessLikeThisRequested(item));
    PrismHaptics.success();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text("Got it. You'll see fewer like this."),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _bloc.add(PersonalizedFeedEvent.lessLikeThisUndone(item, index: index)),
          ),
        ),
      );
  }

  /// Starts loading the first images of a new page, so they are ready when the user scrolls to them.
  void _prefetchNewTiles(BuildContext context, PersonalizedFeedState state, int tileMemCacheHeight) {
    final bool firstBatch = _knownItemIds.isEmpty;
    final List<FeedItemEntity> added = state.items.where((item) => _knownItemIds.add(item.id)).toList();
    if (firstBatch || _lowData) {
      return;
    }
    prefetchTileImages(context, added, memCacheHeight: tileMemCacheHeight);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final int crossAxisCount = wallpaperGridColumns(MediaQuery.sizeOf(context).width);
    final int tileMemCacheHeight = gridTileDecodeHeight(context, crossAxisCount: crossAxisCount);
    return BlocProvider.value(
      value: _bloc,
      child: MultiBlocListener(
        listeners: [
          // The fresh page replaced the cached one with a different first wallpaper: start at the top.
          BlocListener<PersonalizedFeedBloc, PersonalizedFeedState>(
            listenWhen: (prev, curr) =>
                prev.isRefreshing && !curr.isRefreshing && prev.items.firstOrNull?.id != curr.items.firstOrNull?.id,
            listener: (context, state) {
              if (_scrollController.hasClients && _scrollController.offset > 0) {
                _scrollController.jumpTo(0);
              }
            },
          ),
          BlocListener<PersonalizedFeedBloc, PersonalizedFeedState>(
            listenWhen: (prev, curr) => !identical(prev.items, curr.items),
            listener: (context, state) => _prefetchNewTiles(context, state, tileMemCacheHeight),
          ),
        ],
        child: BlocBuilder<PersonalizedFeedBloc, PersonalizedFeedState>(
          buildWhen: (prev, curr) =>
              prev.status != curr.status ||
              !identical(prev.items, curr.items) ||
              prev.actionStatus != curr.actionStatus ||
              prev.isFetchingMore != curr.isFetchingMore ||
              prev.hasMore != curr.hasMore ||
              prev.chip != curr.chip ||
              prev.isRefreshing != curr.isRefreshing,
          builder: (context, state) {
            final prismItems = state.items.whereType<PrismFeedItem>();
            final previewWalls = prismItems.take(_carouselPreviewCount).toList(growable: false);
            final previewSet = prismItems.take(_carouselPreviewCount).toSet();
            final visibleItems = state.items.where((item) => !previewSet.contains(item)).toList(growable: false);

            return RefreshIndicator(
              onRefresh: _refresh,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.depth == 0) {
                    _maybeFetchMore(notification.metrics);
                  }
                  return false;
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  scrollCacheExtent: const ScrollCacheExtent.viewport(1.5),
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    // Carousel: WallOfTheDay + banner + wallpaper previews
                    SliverToBoxAdapter(
                      child: _FeedCarousel(
                        previewWalls: previewWalls,
                        onWallShown: (wall) => _bloc.add(
                          PersonalizedFeedEvent.tilesSeen(<String>[PersonalizedRankingService.canonicalKey(wall)]),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Column(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text('For you', style: PrismTextStyles.editorialTitle(context))),
                                IconButton(
                                  onPressed: widget.onTuneTap == null
                                      ? null
                                      : () {
                                          PrismHaptics.tap();
                                          widget.onTuneTap!();
                                        },
                                  tooltip: 'Tune your feed',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.tune_rounded),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 2,
                            child: state.isRefreshing
                                ? const LinearProgressIndicator(semanticsLabel: 'Updating')
                                : null,
                          ),
                        ],
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: HomeChipRailDelegate(
                        selected: state.chip,
                        onSelected: (chip) => _bloc.add(PersonalizedFeedEvent.chipSelected(chip)),
                      ),
                    ),
                    ..._contentSlivers(context, state, visibleItems, crossAxisCount, tileMemCacheHeight),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _contentSlivers(
    BuildContext context,
    PersonalizedFeedState state,
    List<FeedItemEntity> visibleItems,
    int crossAxisCount,
    int tileMemCacheHeight,
  ) {
    switch (state.chip) {
      case HomeFeedChip.forYou:
        return _forYouSlivers(context, state, visibleItems, crossAxisCount, tileMemCacheHeight);
      case HomeFeedChip.latest:
        return <Widget>[
          PagedChipSliver(
            bloc: _chipBloc(HomeFeedChip.latest)!,
            failureTitle: "Couldn't load the latest wallpapers",
            emptyTitle: 'No wallpapers yet',
            emptyBody: 'Pull down to refresh.',
            crossAxisCount: crossAxisCount,
            tileMemCacheHeight: tileMemCacheHeight,
          ),
        ];
      case HomeFeedChip.following:
        if (_showsSignIn(HomeFeedChip.following)) {
          return const <Widget>[SliverToBoxAdapter(child: SignInPrompt(feature: 'following'))];
        }
        return <Widget>[
          PagedChipSliver(
            bloc: _chipBloc(HomeFeedChip.following)!,
            failureTitle: "Couldn't load your following feed",
            emptyTitle: 'Follow creators to see their new wallpapers here',
            emptyActionLabel: 'Find creators',
            onEmptyAction: () => unawaited(context.router.push(const UserSearchRoute())),
            crossAxisCount: crossAxisCount,
            tileMemCacheHeight: tileMemCacheHeight,
          ),
        ];
      case HomeFeedChip.popular:
        return <Widget>[
          PagedChipSliver(
            bloc: _chipBloc(HomeFeedChip.popular)!,
            failureTitle: "Couldn't load popular wallpapers",
            emptyTitle: 'No popular wallpapers yet',
            emptyBody: 'Pull down to refresh.',
            crossAxisCount: crossAxisCount,
            tileMemCacheHeight: tileMemCacheHeight,
          ),
        ];
    }
  }

  List<Widget> _forYouSlivers(
    BuildContext context,
    PersonalizedFeedState state,
    List<FeedItemEntity> visibleItems,
    int crossAxisCount,
    int tileMemCacheHeight,
  ) {
    if (state.items.isEmpty) {
      if (state.status == LoadStatus.initial || state.status == LoadStatus.loading) {
        return const <Widget>[SliverToBoxAdapter(child: LoadingCards(useFeedLayout: true))];
      }
      if (state.status == LoadStatus.failure) {
        return <Widget>[
          SliverToBoxAdapter(
            child: GlintState(
              kind: GlintStateKind.error,
              title: "Couldn't load your feed",
              body: 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: () => unawaited(_refresh()),
            ),
          ),
        ];
      }
    }
    return <Widget>[
      SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: PrismFeedLayout.gridTileAspectRatio,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final FeedItemEntity item = visibleItems[index];
          _bloc.add(PersonalizedFeedEvent.tilesSeen(<String>[PersonalizedRankingService.canonicalKey(item)]));
          return KeyedSubtree(
            key: ValueKey<String>(item.id),
            child: WallpaperTile(
              item: item,
              index: index,
              crossAxisCount: crossAxisCount,
              memCacheHeight: tileMemCacheHeight,
              quickActions: true,
              onShowLessLikeThis: () => _lessLikeThis(item),
            ),
          );
        }, childCount: visibleItems.length),
      ),
      SliverToBoxAdapter(child: _bottomState(context, state)),
    ];
  }

  Widget _bottomState(BuildContext context, PersonalizedFeedState state) {
    if (state.items.isEmpty) {
      return GlintState(
        kind: GlintStateKind.empty,
        title: 'Shape this feed',
        body: 'Follow creators or choose interests so we can surface more of what you like.',
        actionLabel: widget.onTuneTap == null ? null : 'Tune your feed',
        onAction: widget.onTuneTap,
      );
    }

    if (state.actionStatus == ActionStatus.failure && !state.isFetchingMore) {
      return Padding(
        padding: PrismFeedLayout.contentStatePadding,
        child: Center(
          child: TextButton(
            onPressed: () {
              PrismHaptics.tap();
              context.read<PersonalizedFeedBloc>().add(const PersonalizedFeedEvent.fetchMoreRequested());
            },
            child: const Text("Couldn't load more. Try again"),
          ),
        ),
      );
    }

    if (state.isFetchingMore) {
      return const FeedLoadingMore();
    }

    if (state.hasMore) {
      return const SizedBox(height: PrismFeedLayout.endOfPageSpacerHeight);
    }

    return const Padding(
      padding: PrismFeedLayout.contentStatePadding,
      child: PersonalizedFeedEditorialNote(
        title: "You're caught up",
        detail: 'Pull down to refresh — new picks will land here.',
      ),
    );
  }
}

class _FeedCarousel extends StatefulWidget {
  const _FeedCarousel({required this.previewWalls, required this.onWallShown});

  final List<PrismFeedItem> previewWalls;
  final ValueChanged<PrismFeedItem> onWallShown;

  @override
  State<_FeedCarousel> createState() => _FeedCarouselState();
}

class _FeedCarouselState extends State<_FeedCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final previewWalls = widget.previewWalls;
    final bool hasWotd = context.watch<WotdBloc>().state.entity != null;
    final int slideOffset = hasWotd ? 2 : 1;
    final int slideCount = slideOffset + previewWalls.length;
    final height = MediaQuery.of(context).size.width * PrismFeedLayout.carouselHeightRatio;
    final int memCacheHeight = (height * MediaQuery.devicePixelRatioOf(context)).round();
    // The Home tab stays built under other tabs and pushed routes. Only turn pages that someone can see.
    final bool visible = TickerMode.valuesOf(context).enabled && (ModalRoute.of(context)?.isCurrent ?? true);
    return SizedBox(
      height: height,
      child: Stack(
        alignment: AlignmentDirectional.bottomEnd,
        children: [
          CarouselSlider.builder(
            itemCount: slideCount,
            options: CarouselOptions(
              height: height,
              viewportFraction: 1.0,
              autoPlay: !context.reduceMotion && visible,
              autoPlayInterval: const Duration(seconds: 5),
              onPageChanged: (index, reason) {
                if (mounted) setState(() => _current = index);
              },
            ),
            itemBuilder: (BuildContext context, int i, int rI) {
              if (hasWotd && i == 0) {
                return const SizedBox.expand(child: WallOfTheDayCard());
              }
              if (i == slideOffset - 1) {
                return GestureDetector(
                  onTap: () {
                    PrismHaptics.tap();
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      PrismImageTile(url: app_state.topImageLink, memCacheHeight: memCacheHeight),
                      Center(
                        child: ColoredBox(
                          color: app_state.bannerTextOn
                              ? Theme.of(
                                  context,
                                ).colorScheme.scrim.withValues(alpha: PrismOverlay.carouselBannerScrimAlpha)
                              : Colors.transparent,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              app_state.bannerTextOn ? app_state.bannerText.toUpperCase() : "",
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              // High-contrast on arbitrary photography under [ColorScheme.scrim].
                              style: PrismTextStyles.carouselBannerHeadline(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final int feedIndex = i - slideOffset;
              final PrismFeedItem wall = previewWalls[feedIndex];
              widget.onWallShown(wall);
              return Semantics(
                button: true,
                label: wall.semanticLabel,
                child: GestureDetector(
                  onTap: () {
                    PrismHaptics.tap();
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
                    context.router.push(WallpaperDetailRoute(entity: wall));
                  },
                  child: PremiumCornerBanner(
                    isPremiumWall: isPremiumWall(
                      app_state.premiumCollections,
                      wall.wallpaper.collections ?? const <String>[],
                    ),
                    child: SizedBox.expand(
                      child: PrismImageTile(
                        url: wall.thumbnailUrl,
                        fallbackUrl: wall.fullUrl,
                        memCacheHeight: memCacheHeight,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          CarouselDots(current: _current.clamp(0, slideCount - 1), count: slideCount),
        ],
      ),
    );
  }
}
