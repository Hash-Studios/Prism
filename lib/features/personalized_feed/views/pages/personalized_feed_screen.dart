import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/core/analytics/trackers/wallpaper_impression.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/debug/performance_probe.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_feed_settings.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/home/feed_scroll.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/ads/data/ad_experiment_config.dart';
import 'package:Prism/features/ads/views/widgets/experimental_inline_ad.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/creator_directory/views/widgets/creators_section.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/features/moods/biz/moods_cubit.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/views/widgets/mood_chip_row.dart';
import 'package:Prism/features/moods/views/widgets/mood_row.dart';
import 'package:Prism/features/navigation/views/widgets/prism_top_app_bar.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/following_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/popular_feed_bloc.j.dart';
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
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/features/wallpaper_history/data/history_wall_stores.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/history_wall.dart';
import 'package:Prism/features/wallpaper_history/views/widgets/pick_up_row.dart';
import 'package:Prism/features/weekly_challenges/views/widgets/weekly_challenge_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Grid rows after which a mood row sits in the For you grid. The first mood row follows the fourth row, the second the
/// twelfth.
const List<int> _moodRowGridRows = <int>[4, 12];

/// Grid rows before the "Pick up where you left off" row.
const int _pickUpGridRows = 2;

@visibleForTesting
int? forYouAdIndex(int itemCount, int columns) {
  if (columns <= 0) return null;
  final int index = 14 * columns;
  return itemCount >= index + columns ? index : null;
}

/// Splits the For you grid into chunks. Each chunk is a range of tiles, and [rowAfter] is the mood row that follows it.
@visibleForTesting
List<(int start, int end, MoodList? rowAfter)> forYouChunks(int itemCount, int columns, List<MoodList> rowMoods) {
  final List<(int start, int end, MoodList? rowAfter)> chunks = <(int start, int end, MoodList? rowAfter)>[];
  int start = 0;
  for (int i = 0; i < rowMoods.length && i < _moodRowGridRows.length; i++) {
    final int split = _moodRowGridRows[i] * columns;
    if (itemCount < split) break;
    chunks.add((start, split, rowMoods[i]));
    start = split;
  }
  if (start < itemCount || chunks.isEmpty) chunks.add((start, itemCount, null));
  return chunks;
}

class PersonalizedFeedScreen extends StatefulWidget {
  const PersonalizedFeedScreen({super.key, this.onTuneTap, this.sessionStartedAt});

  final VoidCallback? onTuneTap;
  final DateTime? sessionStartedAt;

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
  late final DateTime _sessionStart = widget.sessionStartedAt ?? DateTime.now();
  RecentlyViewedStore? _viewedHistory;
  SyncedHistoryStore? _syncedHistory;
  late final TrendingBloc _trending;
  late final TabController _tabs;
  final ScrollController _scrollController = ScrollController();
  LatestFeedBloc? _latest;
  FollowingFeedBloc? _following;
  PopularFeedBloc? _popular;
  late final MoodsCubit _moods;
  final Set<String> _knownItemIds = <String>{};
  WallpaperImpressionSession _impressions = WallpaperImpressionSession();
  int _refreshVersion = 0;
  int _moodRowsRevision = 0;
  int _moodLoadVersion = 0;
  bool _moodsReady = false;

  bool get _showAi =>
      !getIt.isRegistered<SettingsLocalDataSource>() || AiContentFilter.showsAi(getIt<SettingsLocalDataSource>());

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<PersonalizedFeedBloc>();
    _trending = getIt<TrendingBloc>()..add(const TrendingEvent.started());
    _moods = getIt<MoodsCubit>();
    unawaited(_loadHomeMoods());
    _tabs = TabController(length: HomeFeedChip.values.length, vsync: this, initialIndex: _bloc.state.chip.index);
    personalizedFeedSettingsRevision.addListener(_onFeedSettingsChanged);
    if (getIt.isRegistered<RecentlyViewedStore>()) {
      _viewedHistory = getIt<RecentlyViewedStore>()..addListener(_onHistoryChanged);
    }
    if (getIt.isRegistered<SyncedHistoryStore>()) {
      _syncedHistory = getIt<SyncedHistoryStore>()..addListener(_onHistoryChanged);
    }
    _bloc.add(const PersonalizedFeedEvent.started());
  }

  void _onHistoryChanged() {
    if (mounted) setState(() {});
  }

  void _onFeedSettingsChanged() {
    if (mounted) {
      _reloadMoodRows(resetImpressions: true);
      _bloc.add(const PersonalizedFeedEvent.settingsChanged());
      _trending.add(const TrendingEvent.refreshRequested());
      _latest?.add(const PagedFeedEvent.refreshRequested());
      _following?.add(const PagedFeedEvent.refreshRequested());
      _popular?.add(const PagedFeedEvent.refreshRequested());
    }
  }

  void _reloadMoodRows({bool resetImpressions = false}) {
    if (!mounted) return;
    setState(() {
      if (resetImpressions) _impressions = WallpaperImpressionSession();
      _moodRowsRevision++;
    });
  }

  Future<bool> _loadHomeMoods() async {
    final int request = ++_moodLoadVersion;
    await _moods.load();
    if (!mounted || request != _moodLoadVersion) return false;
    setState(() => _moodsReady = true);
    return true;
  }

  @override
  void dispose() {
    personalizedFeedSettingsRevision.removeListener(_onFeedSettingsChanged);
    _viewedHistory?.removeListener(_onHistoryChanged);
    _syncedHistory?.removeListener(_onHistoryChanged);
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
    final Future<bool> moodsRefreshed = _loadHomeMoods();
    unawaited(
      moodsRefreshed.then((loaded) {
        if (loaded) _reloadMoodRows();
      }),
    );
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

  /// Starts loading the images of a new page below the first screen, so they are ready when the user scrolls to them.
  void _prefetchNewTiles(BuildContext context, PersonalizedFeedState state, int tileMemCacheHeight) {
    final bool firstBatch = _knownItemIds.isEmpty;
    final List<FeedItemEntity> added = state.items.where((item) => _knownItemIds.add(item.id)).toList();
    // The first page is on screen already up to the first screen of tiles. Later pages append below it.
    prefetchTileImages(
      context,
      added,
      memCacheHeight: tileMemCacheHeight,
      skip: firstBatch ? visibleTileCount(context, wallpaperGridColumns(MediaQuery.sizeOf(context).width)) : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final MediaQueryData media = MediaQuery.of(context);
        if (media.size.isEmpty &&
            (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight || constraints.biggest.isEmpty)) {
          return const SizedBox.shrink();
        }
        return MediaQuery(
          data: media.size.isEmpty ? media.copyWith(size: constraints.biggest) : media,
          child: Builder(builder: _buildFeed),
        );
      },
    );
  }

  Widget _buildFeed(BuildContext context) {
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
          BlocBuilder<MoodsCubit, List<MoodList>>(
            bloc: _moods,
            builder: (context, moods) => BlocSelector<TrendingBloc, TrendingState, List<PrismWallpaper>>(
              bloc: _trending,
              selector: (trending) => trending.walls,
              builder: (context, weekWalls) => _forYouSliver(
                context,
                state,
                weekWalls,
                _moodsReady ? moods : const <MoodList>[],
                crossAxisCount,
                tileMemCacheHeight,
              ),
            ),
          ),
        ];
      case HomeFeedChip.latest:
        return <Widget>[
          PagedChipSliver(
            bloc: _chipBloc(HomeFeedChip.latest)!,
            showAi: _showAi,
            failureTitle: context.l10n.wallpaperFeedLatestLoadError,
            emptyTitle: context.l10n.accountNoWallpapersYet,
            emptyBody: context.l10n.wallpaperFeedPullToRefresh,
            crossAxisCount: crossAxisCount,
            tileMemCacheHeight: tileMemCacheHeight,
          ),
        ];
      case HomeFeedChip.following:
        if (_showsSignIn(HomeFeedChip.following)) {
          return <Widget>[SliverToBoxAdapter(child: SignInPrompt(feature: context.l10n.accountFollowing))];
        }
        return <Widget>[
          PagedChipSliver(
            bloc: _chipBloc(HomeFeedChip.following)!,
            showAi: _showAi,
            failureTitle: context.l10n.wallpaperFeedFollowingLoadError,
            emptyTitle: context.l10n.wallpaperFeedFollowingEmptyTitle,
            emptyActionLabel: context.l10n.accountFindCreators,
            onEmptyAction: () => unawaited(context.router.push(const UserSearchRoute())),
            crossAxisCount: crossAxisCount,
            tileMemCacheHeight: tileMemCacheHeight,
          ),
        ];
      case HomeFeedChip.trending:
        return <Widget>[
          TrendingChipSliver(
            bloc: _trending,
            crossAxisCount: crossAxisCount,
            tileMemCacheHeight: tileMemCacheHeight,
            showAi: _showAi,
          ),
        ];
      case HomeFeedChip.popular:
        return <Widget>[
          PagedChipSliver(
            bloc: _chipBloc(HomeFeedChip.popular)!,
            showAi: _showAi,
            failureTitle: context.l10n.wallpaperFeedPopularLoadError,
            emptyTitle: context.l10n.wallpaperFeedPopularEmptyTitle,
            emptyBody: context.l10n.wallpaperFeedPullToRefresh,
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
    List<MoodList> moods,
    int crossAxisCount,
    int tileMemCacheHeight,
  ) {
    final List<FeedItemEntity> filteredItems = AiContentFilter.filterFeedItems(state.items, showAi: _showAi);
    final PersonalizedFeedState visibleState = state.copyWith(items: filteredItems);
    final DateTime now = DateTime.now();
    final List<PrismWallpaper> boostedWalls = weekWalls
        .where((wall) => wall.isBoostedAt(now) && (_showAi || !AiContentFilter.isAi(wall)))
        .toList(growable: false);
    final Set<String> boostedIds = <String>{for (final PrismWallpaper wall in boostedWalls) wall.id};
    final List<PrismFeedItem> previewWalls = visibleState.items
        .whereType<PrismFeedItem>()
        .where((item) => !boostedIds.contains(item.id))
        .take(_carouselPreviewCount)
        .toList(growable: false);
    final Set<String> shownInCarousel = <String>{...boostedIds, for (final PrismFeedItem item in previewWalls) item.id};
    final List<FeedItemEntity> visibleItems = visibleState.items
        .where((item) => item is! PrismFeedItem || !shownInCarousel.contains(item.id))
        .toList(growable: false);
    final bool loadingFirstPage =
        state.items.isEmpty && (state.status == LoadStatus.initial || state.status == LoadStatus.loading);
    if (visibleItems.isNotEmpty) PerformanceProbe.markOnce('home.grid_first_paint');
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
                    onWallShown: (wall) => _bloc.add(PersonalizedFeedEvent.tilesSeen(<String>[wall.canonicalKey])),
                  ),
          ),
        ),
        if (!loadingFirstPage)
          SliverToBoxAdapter(child: WeeklyChallengeCard(key: ValueKey('challenge-$_moodRowsRevision'))),
        if (!loadingFirstPage) SliverToBoxAdapter(child: MoodChipRow(moods: moods)),
        ..._forYouGridSlivers(context, visibleState, visibleItems, moods, crossAxisCount, tileMemCacheHeight),
      ],
    );
  }

  List<Widget> _forYouGridSlivers(
    BuildContext context,
    PersonalizedFeedState state,
    List<FeedItemEntity> visibleItems,
    List<MoodList> moods,
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
    final List<MoodList> rowMoods = rowMoodsFor(moods, DateTime.now());
    final List<(int start, int end, MoodList? rowAfter)> chunks = forYouChunks(
      visibleItems.length,
      crossAxisCount,
      rowMoods,
    );
    Widget grid(int start, int end) {
      final gridItems = start == 0 && end == visibleItems.length ? null : visibleItems.sublist(start, end);
      return SliverPadding(
        padding: PrismFeedLayout.gridPadding,
        sliver: SliverGrid(
          gridDelegate: PrismWallGrid.delegate(
            context,
            footerHeight: favouriteFooterHeight,
            columns: crossAxisCount,
            spacing: PrismFeedLayout.gridSpacing,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final FeedItemEntity item = visibleItems[start + index];
            return KeyedSubtree(
              key: ValueKey<String>(item.id),
              child: FeedWallTile(
                item: item,
                index: start + index,
                crossAxisCount: crossAxisCount,
                memCacheHeight: tileMemCacheHeight,
                onShowLessLikeThis: () => _lessLikeThis(item),
                onVisible: () => _bloc.add(PersonalizedFeedEvent.tilesSeen(<String>[item.canonicalKey])),
                feed: visibleItems,
                gridItems: gridItems,
              ),
            );
          }, childCount: end - start),
        ),
      );
    }

    // The pick-up row sits after the second grid row, so the feed still starts on the first screen.
    final List<HistoryWall> pickUp = pickUpWallsForSession(now: _sessionStart);
    final int? pickUpAt = pickUp.isEmpty || visibleItems.isEmpty
        ? null
        : math.min(_pickUpGridRows * crossAxisCount, chunks.first.$2);
    // Leave two wallpaper rows after the second mood row and content after the ad.
    final int? adAt = forYouAdIndex(visibleItems.length, crossAxisCount);
    List<Widget> gridWithAd(int start, int end) => <Widget>[
      if (adAt != null && start < adAt && adAt < end) ...<Widget>[
        grid(start, adAt),
        const DeferredAdSliver(child: ExperimentalInlineAd(format: AdExperimentFormat.native, active: true)),
        grid(adAt, end),
      ] else
        grid(start, end),
    ];
    // The creators row sits four wallpaper rows into the second chunk. With one chunk it goes after the whole chunk.
    final int? creatorsAt = chunks.length > 1 ? math.min(chunks[1].$1 + 4 * crossAxisCount, chunks[1].$2) : null;
    return <Widget>[
      for (int i = 0; i < chunks.length; i++) ...<Widget>[
        if (i == 0 && pickUpAt != null) ...<Widget>[
          ...gridWithAd(chunks[i].$1, pickUpAt),
          SliverToBoxAdapter(child: PickUpRow(walls: pickUp)),
          if (pickUpAt < chunks[i].$2) ...gridWithAd(pickUpAt, chunks[i].$2),
        ] else if (i == 1 && creatorsAt != null) ...<Widget>[
          ...gridWithAd(chunks[i].$1, creatorsAt),
          const SliverToBoxAdapter(child: CreatorsSection(source: 'home')),
          if (creatorsAt < chunks[i].$2) ...gridWithAd(creatorsAt, chunks[i].$2),
        ] else
          ...gridWithAd(chunks[i].$1, chunks[i].$2),
        if (chunks[i].$3 case final MoodList rowAfter)
          SliverToBoxAdapter(
            child: MoodRow(
              key: ValueKey<String>('mood-row-${rowAfter.mood.id}-$_moodRowsRevision'),
              list: rowAfter,
              slot: i,
            ),
          ),
        if (i == 0 && chunks.length == 1) const SliverToBoxAdapter(child: CreatorsSection(source: 'home')),
      ],
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
