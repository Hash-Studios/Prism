import 'dart:async';

import 'package:Prism/core/analytics/trackers/wallpaper_impression.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/home/feed_scroll.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/features/navigation/views/widgets/prism_top_app_bar.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/following_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/popular_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/data/personalized_ranking_service.dart';
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_carousel.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_loading_more.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_wall_tile.dart';
import 'package:Prism/features/personalized_feed/views/widgets/home_feed_tab_bar.dart';
import 'package:Prism/features/personalized_feed/views/widgets/paged_chip_sliver.dart';
import 'package:Prism/features/personalized_feed/views/widgets/prefetch_tiles.dart';
import 'package:Prism/features/personalized_feed/views/widgets/trending_chip_sliver.dart';
import 'package:Prism/features/prism_feed/biz/bloc/latest_feed_bloc.j.dart';
import 'package:Prism/features/prism_feed/biz/bloc/paged_feed_bloc.j.dart';
import 'package:Prism/features/session/data/low_data_mode.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PersonalizedFeedScreen extends StatefulWidget {
  const PersonalizedFeedScreen({super.key, this.onTuneTap});

  final VoidCallback? onTuneTap;

  /// Height of the status bar strip, the top bar and the tabs together, for things that sit under the header.
  static double headerHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + PrismTopAppBar.height + HomeFeedTabBar.height;

  @override
  State<PersonalizedFeedScreen> createState() => _PersonalizedFeedScreenState();
}

class _PersonalizedFeedScreenState extends State<PersonalizedFeedScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  static const int _carouselPreviewCount = PrismFeedLayout.carouselPreviewCount;

  late final PersonalizedFeedBloc _bloc;
  late final TrendingBloc _trending;
  late final TabController _tabs;
  final ScrollController _scrollController = ScrollController();
  LatestFeedBloc? _latest;
  FollowingFeedBloc? _following;
  PopularFeedBloc? _popular;
  final Set<String> _knownItemIds = <String>{};
  WallpaperImpressionSession _impressions = WallpaperImpressionSession();
  int _refreshVersion = 0;

  @override
  bool get wantKeepAlive => true;

  /// Replaced by the Data saver setting once it exists.
  bool get _lowData => LowDataMode.enabled.value;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<PersonalizedFeedBloc>();
    _trending = getIt<TrendingBloc>()..add(const TrendingEvent.started());
    _tabs = TabController(length: HomeFeedChip.values.length, vsync: this, initialIndex: _bloc.state.chip.index);
    personalizedFeedSettingsRevision.addListener(_onFeedSettingsChanged);
    _bloc.add(const PersonalizedFeedEvent.started());
  }

  void _onFeedSettingsChanged() {
    if (mounted) {
      setState(() => _impressions = WallpaperImpressionSession());
      _bloc.add(const PersonalizedFeedEvent.settingsChanged());
    }
  }

  @override
  void dispose() {
    personalizedFeedSettingsRevision.removeListener(_onFeedSettingsChanged);
    _scrollController.dispose();
    _tabs.dispose();
    unawaited(_bloc.close());
    unawaited(_trending.close());
    unawaited(_latest?.close());
    unawaited(_following?.close());
    unawaited(_popular?.close());
    super.dispose();
  }

  /// The list behind a chip that pages through wallpapers. It loads the first time its chip is shown.
  PagedFeedBloc? _chipBloc(HomeFeedChip chip) => switch (chip) {
    HomeFeedChip.forYou || HomeFeedChip.trending => null,
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
    if (chip == HomeFeedChip.trending || _showsSignIn(chip)) {
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
    final int refreshVersion = ++_refreshVersion;
    final WallpaperImpressionSession impressions = _impressions;
    PrismHaptics.impact();
    final HomeFeedChip chip = _bloc.state.chip;
    if (chip == HomeFeedChip.trending) {
      final Future<TrendingState> settled = _trending.stream.firstWhere((s) => s.status != LoadStatus.loading);
      _trending.add(const TrendingEvent.refreshRequested());
      final TrendingState result = await settled.timeout(const Duration(seconds: 30), onTimeout: () => _trending.state);
      if (mounted &&
          refreshVersion == _refreshVersion &&
          identical(impressions, _impressions) &&
          _bloc.state.chip == chip &&
          result.status == LoadStatus.success) {
        setState(() => _impressions = WallpaperImpressionSession());
      }
      return;
    }
    if (chip != HomeFeedChip.forYou) {
      if (_showsSignIn(chip)) {
        return;
      }
      final PagedFeedBloc bloc = _chipBloc(chip)!;
      final Future<PagedFeedState> settled = bloc.stream.firstWhere((s) => s.status != LoadStatus.loading);
      bloc.add(const PagedFeedEvent.refreshRequested());
      final PagedFeedState result = await settled.timeout(const Duration(seconds: 30), onTimeout: () => bloc.state);
      if (mounted &&
          refreshVersion == _refreshVersion &&
          identical(impressions, _impressions) &&
          _bloc.state.chip == chip &&
          result.status == LoadStatus.success &&
          result.actionStatus == ActionStatus.success) {
        setState(() => _impressions = WallpaperImpressionSession());
      }
      return;
    }
    final Future<PersonalizedFeedState> settled = _bloc.stream.firstWhere((s) => s.status != LoadStatus.loading);
    _bloc.add(const PersonalizedFeedEvent.refreshRequested());
    // The trending list holds the boosted walls of the carousel.
    _trending.add(const TrendingEvent.started());
    final PersonalizedFeedState result = await settled.timeout(
      const Duration(seconds: 30),
      onTimeout: () => _bloc.state,
    );
    if (mounted &&
        refreshVersion == _refreshVersion &&
        identical(impressions, _impressions) &&
        _bloc.state.chip == chip) {
      if (result.refreshFailed) {
        toasts.error(context.l10n.wallpaperFeedRefreshError);
      } else if (result.status == LoadStatus.success && !result.isRefreshing) {
        setState(() => _impressions = WallpaperImpressionSession());
      }
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
          content: Text(context.l10n.wallpaperGotItFewerLikeThis),
          action: SnackBarAction(
            label: context.l10n.wallpaperFewerLikeThisUndo,
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
    final ColorScheme cs = Theme.of(context).colorScheme;
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
            listenWhen: (prev, curr) => prev.chip != curr.chip,
            listener: (context, state) {
              if (_tabs.index != state.chip.index) {
                _tabs.animateTo(state.chip.index);
              }
              if (_scrollController.hasClients && _scrollController.offset > 0) {
                _scrollController.jumpTo(0);
              }
              // The quest is daily and the screen outlives a day, so every visit reports it.
              if (state.chip == HomeFeedChip.trending) {
                CoinsService.instance.reportQuestEvent(QuestEvent.viewTrending);
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
              prev.isRefreshing != curr.isRefreshing ||
              prev.liveDrop != curr.liveDrop,
          builder: (context, state) {
            // The scroll view starts under the status bar, so the floating header slides in right below the strip and
            // never under it.
            return Column(
              children: <Widget>[
                ColoredBox(
                  color: cs.surface,
                  child: SizedBox(width: double.infinity, height: MediaQuery.paddingOf(context).top),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: cs.primary,
                    backgroundColor: cs.surfaceContainerHigh,
                    edgeOffset: PrismTopAppBar.height + HomeFeedTabBar.height,
                    onRefresh: _refresh,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.depth == 0) {
                          _maybeFetchMore(notification.metrics);
                        }
                        return false;
                      },
                      child: WallpaperImpressionScope(
                        session: _impressions,
                        child: CustomScrollView(
                          controller: _scrollController,
                          scrollCacheExtent: const ScrollCacheExtent.viewport(1.5),
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          slivers: [
                            SliverAppBar(
                              primary: false,
                              floating: true,
                              snap: true,
                              automaticallyImplyLeading: false,
                              centerTitle: false,
                              toolbarHeight: PrismTopAppBar.height,
                              titleSpacing: 0,
                              backgroundColor: cs.surface,
                              surfaceTintColor: Colors.transparent,
                              elevation: 0,
                              scrolledUnderElevation: 0,
                              title: const PrismTopAppBar(),
                              bottom: HomeFeedTabBar(
                                controller: _tabs,
                                selected: state.chip,
                                onSelected: (chip) {
                                  setState(() => _impressions = WallpaperImpressionSession());
                                  _bloc.add(PersonalizedFeedEvent.chipSelected(chip));
                                },
                                onTuneTap: widget.onTuneTap,
                                isRefreshing: state.isRefreshing,
                              ),
                            ),
                            ..._contentSlivers(context, state, crossAxisCount, tileMemCacheHeight),
                            const SliverToBoxAdapter(child: SizedBox(height: PrismSpace.bottomBarClearance)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _contentSlivers(
    BuildContext context,
    PersonalizedFeedState state,
    int crossAxisCount,
    int tileMemCacheHeight,
  ) {
    switch (state.chip) {
      case HomeFeedChip.forYou:
        return <Widget>[
          BlocSelector<TrendingBloc, TrendingState, List<PrismWallpaper>>(
            bloc: _trending,
            selector: (trending) => trending.walls,
            builder: (context, weekWalls) =>
                _forYouSliver(context, state, weekWalls, crossAxisCount, tileMemCacheHeight),
          ),
        ];
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
      case HomeFeedChip.trending:
        return <Widget>[
          TrendingChipSliver(bloc: _trending, crossAxisCount: crossAxisCount, tileMemCacheHeight: tileMemCacheHeight),
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

  /// The For you tab: the carousel, then the grid. Active boosted walls follow the Wall of the Day in the carousel and
  /// are left out of the grid, so a wall shows once.
  Widget _forYouSliver(
    BuildContext context,
    PersonalizedFeedState state,
    List<PrismWallpaper> weekWalls,
    int crossAxisCount,
    int tileMemCacheHeight,
  ) {
    final DateTime now = DateTime.now();
    final List<PrismWallpaper> boostedWalls = weekWalls.where((wall) => wall.isBoostedAt(now)).toList(growable: false);
    final Set<String> boostedIds = <String>{for (final PrismWallpaper wall in boostedWalls) wall.id};
    final List<PrismFeedItem> previewWalls = state.items
        .whereType<PrismFeedItem>()
        .where((item) => !boostedIds.contains(item.id))
        .take(_carouselPreviewCount)
        .toList(growable: false);
    final Set<String> shownInCarousel = <String>{...boostedIds, for (final PrismFeedItem item in previewWalls) item.id};
    final List<FeedItemEntity> visibleItems = state.items
        .where((item) => item is! PrismFeedItem || !shownInCarousel.contains(item.id))
        .toList(growable: false);
    final bool loadingFirstPage =
        state.items.isEmpty && (state.status == LoadStatus.initial || state.status == LoadStatus.loading);
    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.only(bottom: PrismFeedLayout.gridSpacing),
          sliver: SliverToBoxAdapter(
            child: loadingFirstPage
                ? const _CarouselSkeleton()
                : FeedCarousel(
                    boostedWalls: boostedWalls,
                    liveDrop: state.liveDrop,
                    previewWalls: previewWalls,
                    onWallShown: (wall) => _bloc.add(
                      PersonalizedFeedEvent.tilesSeen(<String>[PersonalizedRankingService.canonicalKey(wall)]),
                    ),
                  ),
          ),
        ),
        ..._forYouGridSlivers(context, state, visibleItems, crossAxisCount, tileMemCacheHeight),
      ],
    );
  }

  List<Widget> _forYouGridSlivers(
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
              title: context.l10n.wallpaperFeedLoadError,
              body: context.l10n.wallpaperCheckConnection,
              actionLabel: context.l10n.wallpaperTryAgain,
              onAction: () => unawaited(_refresh()),
            ),
          ),
        ];
      }
    }
    return <Widget>[
      SliverPadding(
        padding: PrismFeedLayout.gridPadding,
        sliver: SliverGrid(
          gridDelegate: PrismWallGrid.delegate(context, columns: crossAxisCount, spacing: PrismFeedLayout.gridSpacing),
          delegate: SliverChildBuilderDelegate((context, index) {
            final FeedItemEntity item = visibleItems[index];
            return KeyedSubtree(
              key: ValueKey<String>(item.id),
              child: FeedWallTile(
                item: item,
                index: index,
                crossAxisCount: crossAxisCount,
                memCacheHeight: tileMemCacheHeight,
                onShowLessLikeThis: () => _lessLikeThis(item),
                onVisible: () =>
                    _bloc.add(PersonalizedFeedEvent.tilesSeen(<String>[PersonalizedRankingService.canonicalKey(item)])),
              ),
            );
          }, childCount: visibleItems.length),
        ),
      ),
      SliverToBoxAdapter(child: _bottomState(context, state, crossAxisCount)),
    ];
  }

  Widget _bottomState(BuildContext context, PersonalizedFeedState state, int columns) {
    if (state.items.isEmpty) {
      return GlintState(
        kind: GlintStateKind.empty,
        title: context.l10n.wallpaperFeedEmptyTitle,
        body: context.l10n.wallpaperFeedEmptyBody,
        actionLabel: widget.onTuneTap == null ? null : context.l10n.wallpaperFeedTuneTitle,
        onAction: widget.onTuneTap,
      );
    }

    if (state.actionStatus == ActionStatus.failure && !state.isFetchingMore) {
      return Padding(
        padding: const EdgeInsets.all(PrismSpace.md),
        child: Center(
          child: PrismButton(
            label: context.l10n.wallpaperFeedLoadMoreError,
            variant: PrismButtonVariant.ghost,
            size: PrismButtonSize.compact,
            onPressed: () {
              context.read<PersonalizedFeedBloc>().add(const PersonalizedFeedEvent.fetchMoreRequested());
            },
          ),
        ),
      );
    }

    if (state.isFetchingMore) {
      return FeedLoadingMore(columns: columns);
    }

    if (state.hasMore) {
      return const SizedBox(height: PrismFeedLayout.endOfPageSpacerHeight);
    }

    return GlintState(
      kind: GlintStateKind.nothingNew,
      glintSize: 64,
      title: context.l10n.wallpaperFeedCaughtUpTitle,
      body: context.l10n.wallpaperFeedCaughtUpBody,
      padding: EdgeInsets.fromLTRB(PrismSpace.xl, PrismSpace.xl, PrismSpace.xl, 0),
    );
  }
}

/// A block where the carousel will be, so the page does not jump when the first walls arrive.
class _CarouselSkeleton extends StatelessWidget {
  const _CarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    return PrismSkeleton(
      child: Padding(
        padding: PrismFeedLayout.gridPadding,
        child: PrismBone(height: feedCarouselCardHeight(context), radius: PrismRadius.lg),
      ),
    );
  }
}
