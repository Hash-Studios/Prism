import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/home/feed_scroll.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/following_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/popular_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/data/personalized_ranking_service.dart';
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_carousel.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_loading_more.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_wall_tile.dart';
import 'package:Prism/features/personalized_feed/views/widgets/home_chip_rail.dart';
import 'package:Prism/features/personalized_feed/views/widgets/paged_chip_sliver.dart';
import 'package:Prism/features/personalized_feed/views/widgets/prefetch_tiles.dart';
import 'package:Prism/features/prism_feed/biz/bloc/latest_feed_bloc.j.dart';
import 'package:Prism/features/prism_feed/biz/bloc/paged_feed_bloc.j.dart';
import 'package:Prism/features/session/data/low_data_mode.dart';
import 'package:Prism/features/trending/views/widgets/trending_strip.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
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
  final GlobalKey<TrendingStripSectionState> _trendingStripKey = GlobalKey<TrendingStripSectionState>();
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
    _trendingStripKey.currentState?.refresh();
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
            final bool loadingFirstPage =
                state.items.isEmpty && (state.status == LoadStatus.initial || state.status == LoadStatus.loading);

            return RefreshIndicator(
              color: cs.primary,
              backgroundColor: cs.surfaceContainerHigh,
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
                    SliverToBoxAdapter(
                      child: loadingFirstPage && state.chip == HomeFeedChip.forYou
                          ? const _CarouselSkeleton()
                          : FeedCarousel(
                              previewWalls: previewWalls,
                              onWallShown: (wall) => _bloc.add(
                                PersonalizedFeedEvent.tilesSeen(<String>[
                                  PersonalizedRankingService.canonicalKey(wall),
                                ]),
                              ),
                            ),
                    ),
                    SliverToBoxAdapter(child: TrendingStripSection(key: _trendingStripKey)),
                    SliverToBoxAdapter(
                      child: _ForYouHeader(onTuneTap: widget.onTuneTap, isRefreshing: state.isRefreshing),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: HomeChipRailDelegate(
                        selected: state.chip,
                        onSelected: (chip) => _bloc.add(PersonalizedFeedEvent.chipSelected(chip)),
                      ),
                    ),
                    ..._contentSlivers(context, state, visibleItems, crossAxisCount, tileMemCacheHeight),
                    const SliverToBoxAdapter(child: SizedBox(height: PrismSpace.bottomBarClearance)),
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
              body: 'Check your connection, then try again.',
              actionLabel: 'Try again',
              onAction: () => unawaited(_refresh()),
            ),
          ),
        ];
      }
    }
    return <Widget>[
      SliverPadding(
        padding: PrismWallGrid.padding,
        sliver: SliverGrid(
          gridDelegate: PrismWallGrid.delegate(context, columns: crossAxisCount),
          delegate: SliverChildBuilderDelegate((context, index) {
            final FeedItemEntity item = visibleItems[index];
            _bloc.add(PersonalizedFeedEvent.tilesSeen(<String>[PersonalizedRankingService.canonicalKey(item)]));
            return KeyedSubtree(
              key: ValueKey<String>(item.id),
              child: FeedWallTile(
                item: item,
                index: index,
                crossAxisCount: crossAxisCount,
                memCacheHeight: tileMemCacheHeight,
                onShowLessLikeThis: () => _lessLikeThis(item),
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
        title: 'Shape this feed',
        body: 'Follow creators or choose interests so we can surface more of what you like.',
        actionLabel: widget.onTuneTap == null ? null : 'Tune your feed',
        onAction: widget.onTuneTap,
      );
    }

    if (state.actionStatus == ActionStatus.failure && !state.isFetchingMore) {
      return Padding(
        padding: const EdgeInsets.all(PrismSpace.md),
        child: Center(
          child: PrismButton(
            label: "Couldn't load more. Try again",
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

    return const GlintState(
      kind: GlintStateKind.nothingNew,
      glintSize: 64,
      title: 'You are all caught up',
      body: 'Pull down to refresh. New picks will land here.',
      padding: EdgeInsets.fromLTRB(PrismSpace.xl, PrismSpace.xl, PrismSpace.xl, 0),
    );
  }
}

class _ForYouHeader extends StatelessWidget {
  const _ForYouHeader({required this.onTuneTap, required this.isRefreshing});

  final VoidCallback? onTuneTap;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            PrismWallGrid.margin + 4,
            PrismSpace.lg,
            PrismWallGrid.margin - 4,
            0,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Semantics(header: true, child: Text('For you', style: PrismTextStyles.sectionTitle(context))),
              ),
              PrismIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Tune your feed',
                onPressed: onTuneTap == null
                    ? null
                    : () {
                        PrismHaptics.tap();
                        onTuneTap!();
                      },
              ),
            ],
          ),
        ),
        // A thin bar shows that cached walls are on screen while the fresh page loads.
        SizedBox(height: 2, child: isRefreshing ? const LinearProgressIndicator(semanticsLabel: 'Updating') : null),
      ],
    );
  }
}

/// A card-shaped block where the carousel will be, so the page does not jump when the first walls arrive.
class _CarouselSkeleton extends StatelessWidget {
  const _CarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    return PrismSkeleton(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PrismWallGrid.margin),
        child: PrismBone(height: feedCarouselCardHeight(context), radius: PrismRadius.lg),
      ),
    );
  }
}
